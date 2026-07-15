# Mirrors the org's existing justfile convention (see aws-repo-template,
# Fomiller/justfiles) but the platform-owned recipes are generated in place
# instead of `curl`-fetched at repo-init time — that's the manual sync this
# POC is meant to replace.
#
# Deliberately not language-conditional beyond lang.*Cmd: every archetype
# gets the same four recipes (build/test/lint/ci), just with different
# bodies, so `just ci` is a stable interface regardless of what's behind it.
{ lang, header }: ''
  ${header}

  build:
      ${lang.buildCmd}

  test:
      ${lang.testCmd}

  lint:
      ${lang.lintCmd}

  ci: lint test build
''
