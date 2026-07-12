{
  description = "fomiller platform flake — declarative repository generation (POC for FOM-51)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    # Consuming repos import this directly:
    #   platform.lib.mkRepository pkgs repoConfig
    # `pkgs` is passed in by the caller so this flake stays system-agnostic.
    lib.mkRepository = pkgs: repoConfig:
      import ./lib/mkRepository.nix { inherit pkgs repoConfig; };
  };
}
