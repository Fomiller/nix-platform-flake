# go-templates (FOM-52)

Exploratory second flake, independent of `../raw-nix/flake.nix`, generating the
same kind of golden files via Go's `text/template` instead of raw Nix
strings. Same `lib.mkRepository = pkgs: repoConfig: { filesDrv; generateApp; }`
interface, so a consuming repo can point `platform.url` at either flake
without changing its call site.

## Implemented

- `Dockerfile` — per-language build, with `overrides.language.buildImage`/
  `runtimeImage` support.
- `.github/workflows/ci.yml` — including `ci.extraSteps.pre`/`.post`.
- `.github/workflows/security.yml` — gated on `ci.security`.
- `.github/workflows/release.yml` — gated on `ci.release`.
- `CODEOWNERS`.

`security.yml`/`release.yml` are gated in `main()`, not in the template:
`baseFiles` holds the always-emitted templates, and `main()` adds the two
conditional entries to a local `files` map based on `cfg.CI.Security`/
`cfg.CI.Release` before the render loop runs — the same "orchestration
layer decides which files exist" style as `raw-nix/`'s `workflows.nix`
(`{ ... } // (if wantSecurity then {...} else {})`). Contrast with
`../jinja/`, where each template gates its own emission internally via
`{% if ci.security %}` wrapping the whole file body, relying on
makejinja's "don't copy an empty-rendered file" behavior — no equivalent
mechanism exists in Go's `text/template` package, so the conditional had
to live in `main.go` instead of `security.yml.tmpl`.

## Not yet ported

`justfile`, `renovate.json`, and the Helm/ArgoCD kubernetes manifests —
same file set as the raw-Nix flake, just not written yet. Add a
`<name>.tmpl` under `templates/`, wire it into `main.go`'s `baseFiles`
map (or a conditional entry in `main()`, if it needs a toggle), and it
follows the same pattern as the files above.

## Notable difference from the raw-Nix flake

Templates use `[[ ]]` as the action delimiter (set via `.Delims("[[",
"]]")` in `main.go`) instead of Go's default `{{ }}`, so files can contain
GitHub Actions' own `${{ ... }}` expressions verbatim — see
`templates/ci.yml.tmpl`'s `concurrency:` block. The raw-Nix flake has to
work around the same collision with a quoted heredoc delimiter
(`'PLATFORM_GENERATED_EOF'`) in `../raw-nix/lib/mkRepository.nix`.

There is no eval-time `files` (path -> content) attrset here, unlike the
raw-Nix flake's `mkRepository.nix` — content only exists once the Go
binary actually runs, which happens at Nix *build* time, not eval time.
