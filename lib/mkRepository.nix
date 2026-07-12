{ pkgs, repoConfig }:
let
  lib = pkgs.lib;

  lang = import ./templates/language.nix { inherit (repoConfig) language; };
  header = import ./header.nix { };

  workflowFiles = import ./templates/workflows.nix { inherit repoConfig lang header; };
  dockerfile = import ./templates/dockerfile.nix { inherit lang header; };
  justfileContent = import ./templates/justfile.nix { inherit lang header; };
  renovateContent = import ./templates/renovate.nix { inherit repoConfig; };
  codeownersContent = import ./templates/codeowners.nix { inherit repoConfig header; };
  kubernetesFiles = import ./templates/kubernetes.nix { inherit repoConfig header; };

  files =
    workflowFiles
    // {
      "Dockerfile" = dockerfile;
      "justfile" = justfileContent;
      "renovate.json" = renovateContent;
      "CODEOWNERS" = codeownersContent;
    }
    // kubernetesFiles;

  writeOneFile = path: content: ''
    mkdir -p "$out/$(dirname ${lib.escapeShellArg path})"
    cat > "$out/${path}" <<'PLATFORM_GENERATED_EOF'
    ${content}
    PLATFORM_GENERATED_EOF
  '';

  writeAllFiles = lib.concatStrings (lib.mapAttrsToList writeOneFile files);

  filesDrv = pkgs.runCommand "repo-files-${repoConfig.name}" { } ''
    mkdir -p "$out"
    ${writeAllFiles}
  '';

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
