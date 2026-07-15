# jinja (makejinja variant)

Third, independent flake, sibling to `../raw-nix/` and `../go-templates/`,
generating the same kind of golden files via
[makejinja](https://github.com/mirkolenz/makejinja) — a Python/Jinja2 CLI
that renders a whole template directory tree in one invocation — instead
of raw Nix strings or a compiled Go program. Same
`lib.mkRepository = pkgs: repoConfig: { filesDrv; generateApp; }`
interface as the other two.

## Implemented

- `Dockerfile` — per-language build, with `overrides.language.buildImage`/
  `runtimeImage` support.
- `.github/workflows/ci.yml` — including `ci.extraSteps.pre`/`.post`.
- `.github/workflows/security.yml` — gated on `ci.security`.
- `.github/workflows/release.yml` — gated on `ci.release`.
- `CODEOWNERS`.

`security.yml`/`release.yml` are wrapped in `{% if ci.security %}`/
`{% if ci.release %}` around the *entire* file body (header include
included), relying on makejinja's default behavior of not copying a file
that rendered empty — confirmed via its own `Skip empty file` log line.
No `lib/mkRepository.nix` changes were needed for either: unlike
`raw-nix/`'s `wantSecurity`/`wantRelease` `//`-merge in `workflows.nix` or
go-templates' `files` map, the toggle lives entirely inside the template.

## Not yet ported

`justfile`, `renovate.json`, kubernetes manifests — add a `<name>.jinja`
under `templates/` (mirroring the output path relative to `templates/`)
and it follows the same pattern as the files above; no changes to
`lib/mkRepository.nix` needed, since makejinja discovers `*.jinja` files
itself.

## Notable differences from the other two flakes

- **The GitHub Actions `${{ ... }}` collision doesn't need custom
  delimiters at all.** First pass used `--delimiter-variable-start
  '[['`/`--delimiter-variable-end ']]'` (like go-templates' `.Delims()`),
  but that's non-standard Jinja — templates stop being renderable by any
  other Jinja tooling without also knowing the custom delimiters. Switched
  to plain Jinja's `{% raw %}...{% endraw %}` block instead (see
  `templates/.github/workflows/ci.yml.jinja`'s `concurrency:` line), which
  keeps `{{ }}`/`{% %}` fully standard everywhere. One real gotcha hit
  along the way: makejinja's default `trim_blocks` strips the newline
  right after a block tag, so `{% endraw %}` immediately followed by a
  newline silently merged the next YAML line onto the same line — fixed
  with Jinja's `+` whitespace-control modifier (`{% endraw +%}`), which
  explicitly disables trim for that one tag.
- **No hand-rolled `indent` helper.** Jinja ships an `indent(width, first)`
  filter — `{{ step | indent(6, true) }}` — unlike the raw-Nix flake's
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
