# Mirrors the org's existing justfile convention (see aws-repo-template,
# Fomiller/justfiles) but the platform-owned recipes are generated in place
# instead of `curl`-fetched at repo-init time — that's the manual sync this
# POC is meant to replace.
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
