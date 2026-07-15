{
  description = "fomiller platform flake (makejinja variant) — same mkRepository interface as ../raw-nix/flake.nix and ../go-templates/flake.nix, generated via makejinja (Jinja2) instead of raw Nix strings or Go text/template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    # Same call site as the other two flakes: platform.lib.mkRepository pkgs
    # repoConfig. Any of the three flakes is a drop-in replacement for
    # another at this interface — that's the whole point of comparing them.
    lib.mkRepository = pkgs: repoConfig:
      import ./lib/mkRepository.nix { inherit pkgs repoConfig; };
  };
}
