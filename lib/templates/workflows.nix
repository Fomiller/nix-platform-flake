{ repoConfig, lang, header }:
let
  ci = repoConfig.ci or {};
  wantSecurity = ci.security or false;
  wantRelease = ci.release or false;

  ciYml = ''
    ${header}
    name: CI

    on:
      pull_request:
      push:
        branches: [main]

    jobs:
      build-test:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
    ${lang.setupStep}
          - name: build
            run: ${lang.buildCmd}
          - name: test
            run: ${lang.testCmd}
          - name: lint
            run: ${lang.lintCmd}
  '';

  securityYml = ''
    ${header}
    name: Security

    on:
      pull_request:
      schedule:
        - cron: "0 6 * * 1"

    jobs:
      scan:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
          - name: trivy fs scan
            uses: aquasecurity/trivy-action@master
            with:
              scan-type: fs
              exit-code: "1"
              severity: CRITICAL,HIGH
  '';

  releaseYml = ''
    ${header}
    name: Release

    on:
      push:
        tags: ["v*"]

    jobs:
      release:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
    ${lang.setupStep}
          - name: build release artifact
            run: ${lang.buildCmd}
          - name: publish
            uses: softprops/action-gh-release@v2

  '';

  # The repo generation workflow itself (nix run .#generate + drift check) is
  # hand-authored per the ticket: "the repository itself owns the generation
  # workflow." It is NOT emitted by the platform flake — see repos/*/.github
  # for the checked-in version.
in
  { ".github/workflows/ci.yml" = ciYml; }
  // (if wantSecurity then { ".github/workflows/security.yml" = securityYml; } else {})
  // (if wantRelease then { ".github/workflows/release.yml" = releaseYml; } else {})
