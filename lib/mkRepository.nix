# The core of the platform flake. Given a repo's declared config, this
# produces:
#   - files      : attrset of { "relative/path" = "file contents"; ... } —
#                  useful for eval/debugging (see the README example).
#   - filesDrv   : a Nix derivation whose $out is a directory tree
#                  containing exactly those files, laid out ready to copy
#                  into a repo.
#   - generateApp: a flake `app` (what `nix run .#generate` executes) that
#                  copies filesDrv's tree into the current working
#                  directory — i.e. the actual generator.
{ pkgs, repoConfig }:
let
  lib = pkgs.lib;

  # Resolve this repo's language archetype (build/test/lint commands, base
  # images, etc — see templates/language.nix) and the shared "do not edit"
  # banner every generated file gets prefixed with.
  langBase = import ./templates/language.nix { inherit (repoConfig) language; };

  # Per-repo escape hatch (see repo.nix's `overrides.language`): overrides
  # any single archetype field — e.g. a newer buildImage — without waiting
  # on a platform release. `//` is right-biased so an override always wins.
  # `dockerBuild` is deliberately computed *after* the merge, from the
  # merged buildImage/runtimeImage, so an image override cascades into the
  # generated Dockerfile instead of silently missing it (a plain `//` over
  # a pre-baked dockerBuild string could not do this).
  langOverrides = repoConfig.overrides.language or { };
  langMerged = langBase // langOverrides;
  lang = langMerged // {
    dockerBuild = langOverrides.dockerBuild or
      (langBase.mkDockerBuild { inherit (langMerged) buildImage runtimeImage; });
  };

  header = import ./header.nix { };

  # Each template module is a pure function: (repoConfig/lang/header) -> an
  # attrset of { path = content; }. Modules that only ever produce one file
  # (Dockerfile, justfile, renovate.json, CODEOWNERS) just return a string
  # and get named below; modules that produce a variable number of files
  # (workflows.nix, kubernetes.nix) return their own path->content attrset
  # directly, keyed on repoConfig's ci/kubernetes toggles.
  workflowFiles = import ./templates/workflows.nix { inherit repoConfig lang header lib; };
  dockerfile = import ./templates/dockerfile.nix { inherit lang header; };
  justfileContent = import ./templates/justfile.nix { inherit lang header; };
  renovateContent = import ./templates/renovate.nix { inherit repoConfig; };
  codeownersContent = import ./templates/codeowners.nix { inherit repoConfig header; };
  kubernetesFiles = import ./templates/kubernetes.nix { inherit repoConfig header; };

  # The full generated tree for this repo, as one flat attrset keyed by
  # path relative to the repo root. `//` is Nix's attrset merge (right
  # side wins on key collision) — workflowFiles/kubernetesFiles contribute
  # a variable number of entries depending on repoConfig.ci/.kubernetes.
  files =
    workflowFiles
    // {
      "Dockerfile" = dockerfile;
      "justfile" = justfileContent;
      "renovate.json" = renovateContent;
      "CODEOWNERS" = codeownersContent;
    }
    // kubernetesFiles;

  # Turns one (path, content) pair into a shell snippet that writes it under
  # $out. mkdir -p handles nested paths like ".github/workflows/ci.yml" or
  # "charts/<name>/Chart.yaml". The heredoc uses a QUOTED delimiter
  # ('PLATFORM_GENERATED_EOF') specifically so bash does NOT try to expand
  # anything inside `content` — several templates emit literal `$` (GitHub
  # Actions' `${{ ... }}` expressions), and without quoting the heredoc
  # marker, bash would try to interpolate those as shell variables.
  writeOneFile = path: content: ''
    mkdir -p "$out/$(dirname ${lib.escapeShellArg path})"
    cat > "$out/${path}" <<'PLATFORM_GENERATED_EOF'
    ${content}
    PLATFORM_GENERATED_EOF
  '';

  # Concatenate one such snippet per file in `files` into a single script.
  writeAllFiles = lib.concatStrings (lib.mapAttrsToList writeOneFile files);

  # Build the whole tree as one derivation. This is what makes the
  # generator reproducible/cacheable: same repoConfig + same platform
  # commit => same filesDrv store path, every time.
  filesDrv = pkgs.runCommand "repo-files-${repoConfig.name}" { } ''
    mkdir -p "$out"
    ${writeAllFiles}
  '';

  # The actual `nix run .#generate` entry point. `--no-preserve=mode` is
  # required because everything under filesDrv is read-only (as all Nix
  # store paths are) — without it, cp would copy that read-only bit into
  # the working tree and a second `generate` run would fail to overwrite.
  # `-f` additionally covers files that already exist and are writable
  # but were, say, chmod'd read-only by a previous run on another OS.
  generateApp = {
    type = "app";
    program = toString (pkgs.writeShellScript "generate" ''
      set -euo pipefail
      cp -rf --no-preserve=mode,ownership "${filesDrv}/." .
      count=$(cd "${filesDrv}" && find . -type f | wc -l | tr -d ' ')
      echo "generate: wrote $count platform-managed files for '${repoConfig.name}'"
    '');
  };
in
{
  inherit files filesDrv generateApp;
}
