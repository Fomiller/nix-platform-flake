{
  description = "fomiller platform flake — declarative repository generation (POC for FOM-51)";

  # This flake has exactly one input: nixpkgs, for pkgs.runCommand /
  # pkgs.writeShellScript / pkgs.lib, used to build the generated files and
  # the `generate` app. There's no flake-utils here because this flake never
  # produces system-specific outputs (packages, apps, devShells) itself —
  # it only exports a plain function (`lib.mkRepository`). Consumer flakes
  # are the ones that need a `system`, and they supply it when they call in.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    # `lib` (as opposed to `packages.<system>` or `apps.<system>`) is the
    # correct place for this: it's a plain attrset of functions, not
    # something Nix needs to build. That's also why it's not keyed by
    # system — mkRepository is system-agnostic until you call it.
    #
    # Consuming repos import this directly:
    #   platform.lib.mkRepository pkgs repoConfig
    #
    # `pkgs` is passed in by the *caller* (not imported here) so this flake
    # never has to pick a system for itself — the consumer's own
    # `import nixpkgs { system = ... }` flows straight through to every
    # template and derivation mkRepository builds.
    lib.mkRepository = pkgs: repoConfig:
      import ./lib/mkRepository.nix { inherit pkgs repoConfig; };
  };
}
