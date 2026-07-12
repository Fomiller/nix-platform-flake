{ repoConfig, lang, header, lib }:
let
  # Nix multi-line strings are dedented at each literal's own definition
  # site, independent of the column an interpolation lands at — so a
  # multi-line value like lang.setupStep needs to be re-indented by hand
  # once spliced into a nested YAML block, or it comes out flush left.
  indent = n: text:
    let
      pad = lib.concatStrings (lib.genList (_: " ") n);
      lines = lib.splitString "\n" text;
    in
      lib.concatStringsSep "\n" (map (l: if l == "" then l else pad + l) lines);

  setupStepAt6 = indent 6 lang.setupStep;

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

    concurrency:
      group: ''${{ github.workflow }}-''${{ github.ref }}
      cancel-in-progress: true

    jobs:
      build-test:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
    ${setupStepAt6}
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
    ${setupStepAt6}
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
