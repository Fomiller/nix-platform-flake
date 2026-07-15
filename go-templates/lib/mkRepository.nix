# Go-templating variant of ../../raw-nix/lib/mkRepository.nix (FOM-52). Same
# repoConfig -> { filesDrv; generateApp; } shape as the raw-Nix-string
# flake, but instead of heredoc strings, repoConfig is serialized to JSON
# and handed to a compiled Go program that renders text/template files.
{ pkgs, repoConfig }:
let
  # repoConfig is a Nix attrset; the Go program only understands JSON, so
  # this is the one conversion point between "declarative repo.nix" and
  # "what the generator actually consumes." builtins.toJSON is exact for
  # the strings/bools/lists repo.nix uses here.
  configJson = pkgs.writeText "repo-config.json" (builtins.toJSON repoConfig);

  # encoding/json, text/template, and embed are all stdlib — nothing to
  # vendor, so vendorHash = null is valid for the same reason it is in
  # nix-go-service/flake.nix.
  generator = pkgs.buildGoModule {
    pname = "platform-generate-go-templates";
    version = "0.1.0";
    src = ./..;
    vendorHash = null;
  };

  filesDrv = pkgs.runCommand "repo-files-${repoConfig.name}-go-templates" { } ''
    mkdir -p "$out"
    ${generator}/bin/platform-generate -config ${configJson} -out "$out"
  '';

  # Same cp pattern as the raw-Nix flake's generateApp — see that file's
  # comment for why --no-preserve=mode,ownership and -f are both needed.
  generateApp = {
    type = "app";
    program = toString (pkgs.writeShellScript "generate" ''
      set -euo pipefail
      cp -rf --no-preserve=mode,ownership "${filesDrv}/." .
      count=$(cd "${filesDrv}" && find . -type f | wc -l | tr -d ' ')
      echo "generate (go-templates): wrote $count platform-managed files for '${repoConfig.name}'"
    '');
  };
in
{
  # Unlike the raw-Nix flake, there's no eval-time `files` attrset here —
  # file content is produced by the Go program at *build* time, not by Nix
  # during eval, so there's no cheap way to inspect a rendered file without
  # first building filesDrv. That asymmetry is itself one of FOM-52's
  # comparison points against the raw-Nix-string approach.
  inherit filesDrv generateApp;
}
