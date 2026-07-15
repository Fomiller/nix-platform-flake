// generate reads a repo.nix-derived JSON config and renders the platform's
// golden files from templates/*.tmpl using Go's text/template instead of
// raw Nix strings (FOM-52). See lib/mkRepository.nix for how the Nix side
// gets a repoConfig attrset into the JSON this program reads.
package main

import (
	"bytes"
	"embed"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"text/template"
)

//go:embed templates
var templateFS embed.FS

type extraSteps struct {
	Pre  []string `json:"pre"`
	Post []string `json:"post"`
}

type ciConfig struct {
	Security   bool       `json:"security"`
	Release    bool       `json:"release"`
	ExtraSteps extraSteps `json:"extraSteps"`
}

type languageOverride struct {
	BuildImage   string `json:"buildImage"`
	RuntimeImage string `json:"runtimeImage"`
}

type overridesConfig struct {
	Language languageOverride `json:"language"`
}

// repoConfig mirrors repo.nix's shape (see ../lib/mkRepository.nix's
// raw-Nix-string counterpart). Only the fields the scaffolded templates
// actually use are here — kubernetes/renovate/justfile fields aren't
// wired up yet (see README.md).
type repoConfig struct {
	Name       string          `json:"name"`
	Language   string          `json:"language"`
	CI         ciConfig        `json:"ci"`
	Overrides  overridesConfig `json:"overrides"`
	Codeowners []string        `json:"codeowners"`
}

// langArchetype is the Go-side equivalent of language.nix's archetypes
// attrset. Duplicated here rather than shared with the raw-Nix flake —
// the two generators are intentionally independent (FOM-52 compares them,
// it doesn't share code between them).
type langArchetype struct {
	BuildImage   string
	RuntimeImage string
	SetupStep    string
	BuildCmd     string
	TestCmd      string
	LintCmd      string
}

var archetypes = map[string]langArchetype{
	"go": {
		BuildImage:   "golang:1.23",
		RuntimeImage: "gcr.io/distroless/static-debian12",
		SetupStep:    "- uses: actions/setup-go@v5\n  with:\n    go-version-file: go.mod\n    cache: true",
		BuildCmd:     "go build ./...",
		TestCmd:      "go test ./... -race -cover",
		LintCmd:      "go vet ./...",
	},
	"rust": {
		BuildImage:   "rust:1.82",
		RuntimeImage: "gcr.io/distroless/cc-debian12",
		SetupStep:    "- uses: dtolnay/rust-toolchain@stable",
		BuildCmd:     "cargo build --release",
		TestCmd:      "cargo test --all-features",
		LintCmd:      "cargo clippy -- -D warnings",
	},
}

// templateData is what every .tmpl file renders against: the repo's own
// config plus its resolved (and possibly overridden) language archetype.
type templateData struct {
	repoConfig
	Lang langArchetype
}

// files maps output path -> template path. Intentionally small: this is
// a scaffold, not full parity with the raw-Nix-string flake yet.
var files = map[string]string{
	"Dockerfile":               "templates/dockerfile.tmpl",
	"CODEOWNERS":               "templates/codeowners.tmpl",
	".github/workflows/ci.yml": "templates/ci.yml.tmpl",
}

var funcs = template.FuncMap{
	// Go's text/template has no built-in multi-line indent, same gap
	// Nix's workflows.nix filled with its own `indent` helper — needed
	// here for the same reason: splicing a multi-line archetype value
	// (Lang.SetupStep) or a repo-supplied extra step into a nested YAML
	// block.
	"indent": func(n int, text string) string {
		pad := strings.Repeat(" ", n)
		lines := strings.Split(text, "\n")
		for i, l := range lines {
			if l != "" {
				lines[i] = pad + l
			}
		}
		return strings.Join(lines, "\n")
	},
}

func main() {
	configPath := flag.String("config", "", "path to repo-config.json")
	outDir := flag.String("out", "", "output directory")
	flag.Parse()
	if *configPath == "" || *outDir == "" {
		fmt.Fprintln(os.Stderr, "usage: generate -config repo-config.json -out DIR")
		os.Exit(1)
	}

	raw, err := os.ReadFile(*configPath)
	must(err)

	var cfg repoConfig
	must(json.Unmarshal(raw, &cfg))

	lang, ok := archetypes[cfg.Language]
	if !ok {
		fmt.Fprintf(os.Stderr, "generate: unsupported language %q\n", cfg.Language)
		os.Exit(1)
	}
	// repoConfig.overrides.language.<field> — Go-templating equivalent of
	// mkRepository.nix's langOverrides merge. Only overrides the fields
	// actually set (empty string means "not overridden").
	if v := cfg.Overrides.Language.BuildImage; v != "" {
		lang.BuildImage = v
	}
	if v := cfg.Overrides.Language.RuntimeImage; v != "" {
		lang.RuntimeImage = v
	}

	header, err := templateFS.ReadFile("templates/header.tmpl")
	must(err)

	data := templateData{repoConfig: cfg, Lang: lang}

	for outPath, tmplPath := range files {
		body := render(tmplPath, data)
		full := filepath.Join(*outDir, outPath)
		must(os.MkdirAll(filepath.Dir(full), 0o755))
		must(os.WriteFile(full, []byte(string(header)+body), 0o644))
	}

	fmt.Printf("generate (go-templates): wrote %d platform-managed files for %q\n", len(files), cfg.Name)
}

// render uses "[[ ]]" instead of the default "{{ }}" specifically so
// templates can contain GitHub Actions' own "${{ ... }}" expressions
// verbatim — the Go-templating equivalent of the raw-Nix flake's quoted
// heredoc delimiter trick, but resolved at the delimiter level instead of
// needing an escape sequence at every use site.
func render(tmplPath string, data templateData) string {
	t := template.Must(
		template.New(filepath.Base(tmplPath)).Delims("[[", "]]").Funcs(funcs).ParseFS(templateFS, tmplPath),
	)
	var buf bytes.Buffer
	must(t.Execute(&buf, data))
	return buf.String()
}

func must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, "generate:", err)
		os.Exit(1)
	}
}
