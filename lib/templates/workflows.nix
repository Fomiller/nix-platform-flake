# Generates .github/workflows/{ci,security,release}.yml. ci.yml is always
# emitted; security.yml and release.yml are only emitted when repo.nix
# opts in via `ci.security`/`ci.release` — this is the "declarative"
# lever mkRepository's example in the ticket shows (`ci = { security =
# true; release = true; }`).
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

  # Both ci.yml and release.yml nest lang.setupStep six spaces deep, under
  # `jobs.<name>.steps:` — computed once and reused so the two workflows
  # can't drift on indentation.
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

  # Not language-specific (a filesystem/dependency scan works the same for
  # any archetype), so unlike ciYml/releaseYml it doesn't touch `lang` at
  # all.
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
  # ci.yml is unconditional; security.yml/release.yml are spliced in only
  # when repo.nix asks for them — this is how a single mkRepository call
  # ends up producing a different file set for go-service (both) vs
  # rust-service (security only). `//` merge with `{}` is a no-op when the
  # toggle is off.
  { ".github/workflows/ci.yml" = ciYml; }
  // (if wantSecurity then { ".github/workflows/security.yml" = securityYml; } else {})
  // (if wantRelease then { ".github/workflows/release.yml" = releaseYml; } else {})
