# makejinja variant of ../../raw-nix/lib/mkRepository.nix, sibling exploration
# to ../../go-templates/lib/mkRepository.nix. Same repoConfig -> { filesDrv;
# generateApp; } shape, but templates are Jinja files rendered by makejinja
# (https://github.com/mirkolenz/makejinja, a Python/Jinja2 CLI that renders
# a whole template directory tree in one invocation) instead of raw Nix
# strings or a compiled Go program.
{ pkgs, repoConfig }:
let
  # Duplicated from raw-nix/lib/templates/language.nix rather than shared —
  # same "generators are intentionally independent" reasoning as
  # go-templates/main.go's archetype table: the point of comparing these
  # three flakes is the templating layer, and reusing one variant's data
  # from another would make the comparison less fair.
  archetypes = {
    go = {
      buildImage = "golang:1.23";
      runtimeImage = "gcr.io/distroless/static-debian12";
      setupStep = ''
        - uses: actions/setup-go@v5
          with:
            go-version-file: go.mod
            cache: true'';
      buildCmd = "go build ./...";
      testCmd = "go test ./... -race -cover";
      lintCmd = "go vet ./...";
    };
    rust = {
      buildImage = "rust:1.82";
      runtimeImage = "gcr.io/distroless/cc-debian12";
      setupStep = ''
        - uses: dtolnay/rust-toolchain@stable'';
      buildCmd = "cargo build --release";
      testCmd = "cargo test --all-features";
      lintCmd = "cargo clippy -- -D warnings";
    };
  };

  langBase = archetypes.${repoConfig.language} or (throw
    "mkRepository (jinja): unsupported language '${repoConfig.language}' (known: ${toString (builtins.attrNames archetypes)})");

  # repoConfig.overrides.language.<field>, same escape hatch as the other
  # two flakes. `//` is right-biased so an override always wins.
  lang = langBase // (repoConfig.overrides.language or { });

  # makejinja's -d/--data accepts JSON directly, so — unlike the raw-Nix
  # flake's YAML-key-ordering problem — there's no need to route through an
  # intermediate format. This is the same conversion point as
  # go-templates/lib/mkRepository.nix's configJson, just consumed by
  # Python/Jinja2 instead of Go's encoding/json.
  templateData = pkgs.writeText "repo-data.json" (builtins.toJSON (repoConfig // { inherit lang; }));

  filesDrv = pkgs.runCommand "repo-files-${repoConfig.name}-jinja"
    { nativeBuildInputs = [ pkgs.makejinja ]; }
    ''
      mkdir -p "$out"
      makejinja \
        -i ${../templates} \
        -o "$out" \
        -d ${templateData} \
        --exclude-pattern '_*'
    '';

  # Same cp pattern as the other two flakes' generateApp.
  generateApp = {
    type = "app";
    program = toString (pkgs.writeShellScript "generate" ''
      set -euo pipefail
      cp -rf --no-preserve=mode,ownership "${filesDrv}/." .
      count=$(cd "${filesDrv}" && find . -type f | wc -l | tr -d ' ')
      echo "generate (jinja): wrote $count platform-managed files for '${repoConfig.name}'"
    '');
  };
in
{
  # No eval-time `files` attrset here either, for the same reason as
  # go-templates: content only exists once makejinja actually runs, at Nix
  # build time.
  inherit filesDrv generateApp;
}
