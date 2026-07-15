{
  description = "fomiller platform flake (go-templates variant, FOM-52) — same mkRepository interface as ../raw-nix/flake.nix, generated via Go text/template instead of raw Nix strings";

  # Same shape as ../raw-nix/flake.nix: one input, no flake-utils, because
  # this flake only exports a plain function that a caller supplies pkgs to.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    # Same call site as the raw-Nix flake: platform.lib.mkRepository pkgs
    # repoConfig. A consumer repo can point `platform.url` at either this
    # flake or ../raw-nix/flake.nix (with &dir=raw-nix) without changing
    # how it calls in — the whole point of FOM-52 is comparing the two
    # behind an identical interface.
    lib.mkRepository = pkgs: repoConfig:
      import ./lib/mkRepository.nix { inherit pkgs repoConfig; };
  };
}
