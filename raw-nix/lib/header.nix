# The "do not edit, this is generated" banner every platform-managed file
# gets prefixed with (FOM-51's "generated file ownership" requirement).
#
# `commentPrefix` defaults to "#" (works for YAML, Dockerfile, justfile,
# shell). renovate.nix doesn't use this module at all — JSON has no
# comment syntax, so it hand-writes the equivalent banner as `//` lines,
# which Renovate's own JSON5 config parser accepts. If a future template
# needs a different comment style (e.g. HTML's `<!-- -->`), call this with
# `{ commentPrefix = "//"; }` or similar rather than writing a new banner
# from scratch.
{ commentPrefix ? "#" }:
''
${commentPrefix} GENERATED FILE — managed by the fomiller platform flake.
${commentPrefix} Do not edit manually: changes will be overwritten by `nix run .#generate`.
${commentPrefix} To customize, edit repo.nix in this repository instead.
''
