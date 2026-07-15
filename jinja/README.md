# jinja (makejinja variant)

Third, independent flake, sibling to `../raw-nix/` and `../go-templates/`,
generating the same kind of golden files via
[makejinja](https://github.com/mirkolenz/makejinja) — a Python/Jinja2 CLI
that renders a whole template directory tree in one invocation — instead
of raw Nix strings or a compiled Go program. Same
`lib.mkRepository = pkgs: repoConfig: { filesDrv; generateApp; }`
interface as the other two.

## Implemented (scaffold)

- `Dockerfile` — per-language build, with `overrides.language.buildImage`/
  `runtimeImage` support.
- `.github/workflows/ci.yml` — including `ci.extraSteps.pre`/`.post`.
- `CODEOWNERS`.

Same scope as `../go-templates/`, for a direct comparison.

## Not yet ported

`security.yml`, `release.yml`, `justfile`, `renovate.json`, kubernetes
manifests — add a `<name>.jinja` under `templates/` (mirroring the output
path relative to `templates/`) and it follows the same pattern as the
three above; no changes to `lib/mkRepository.nix` needed, since makejinja
discovers `*.jinja` files itself.

## Notable differences from the other two flakes

- **No custom code for the delimiter collision.** GitHub Actions'
  `${{ ... }}` only collides with Jinja's *variable* delimiter (`{{ }}`),
  not its block (`{% %}`) or comment (`{# #}`) delimiters — so
  `lib/mkRepository.nix` only overrides
  `--delimiter-variable-start`/`--delimiter-variable-end` to `[[`/`]]`,
  leaving `{% if %}`/`{% for %}` untouched. More surgical than
  go-templates' single `.Delims()` call, which had to move every action's
  delimiters at once because Go's text/template only has one delimiter
  pair, not a separate one per construct.
- **No hand-rolled `indent` helper.** Jinja ships an `indent(width, first)`
  filter — `[[ step | indent(6, true) ]]` — unlike the raw-Nix flake's
  custom `indent` function in `workflows.nix` or go-templates' equivalent
  `template.FuncMap` entry in `main.go`.
- **Whole-directory-tree rendering is built in.** `makejinja -i templates
  -o $out` walks and renders every `*.jinja` file itself; there's no
  Go-style `files` map in `main.go` listing out-path -> template-path by
  hand — add a template file in the right place under `templates/` and
  it's picked up automatically.
- **No compiled binary.** `lib/mkRepository.nix` doesn't need
  `buildGoModule`/`vendorHash` — `pkgs.makejinja` is used directly as a
  `nativeBuildInput`, since it's already a packaged CLI tool, not code we
  wrote and compile ourselves.

Same asymmetry as go-templates against the raw-Nix flake: no eval-time
`files` (path -> content) attrset, since content only exists once
makejinja actually runs, at Nix build time.
