# go-templates (FOM-52)

Exploratory second flake, independent of `../flake.nix`, generating the
same kind of golden files via Go's `text/template` instead of raw Nix
strings. Same `lib.mkRepository = pkgs: repoConfig: { filesDrv; generateApp; }`
interface, so a consuming repo can point `platform.url` at either flake
without changing its call site.

## Implemented (scaffold)

- `Dockerfile` — per-language build, with `overrides.language.buildImage`/
  `runtimeImage` support.
- `.github/workflows/ci.yml` — including `ci.extraSteps.pre`/`.post`.
- `CODEOWNERS`.

## Not yet ported

`security.yml`, `release.yml`, `justfile`, `renovate.json`, and the
Helm/ArgoCD kubernetes manifests — same file set as the raw-Nix flake,
just not written yet. Add a `<name>.tmpl` under `templates/`, wire it into
`main.go`'s `files` map, and it follows the same pattern as the three
above.

## Notable difference from the raw-Nix flake

Templates use `[[ ]]` as the action delimiter (set via `.Delims("[[",
"]]")` in `main.go`) instead of Go's default `{{ }}`, so files can contain
GitHub Actions' own `${{ ... }}` expressions verbatim — see
`templates/ci.yml.tmpl`'s `concurrency:` block. The raw-Nix flake has to
work around the same collision with a quoted heredoc delimiter
(`'PLATFORM_GENERATED_EOF'`) in `../lib/mkRepository.nix`.

There is no eval-time `files` (path -> content) attrset here, unlike the
raw-Nix flake's `mkRepository.nix` — content only exists once the Go
binary actually runs, which happens at Nix *build* time, not eval time.
