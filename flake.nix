{
  description = "NixOS configuration for nixos";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Dotfiles (separate repo, managed with the `dots` tool — not a flake).
    # Pinned so the exact dotfiles commit is locked alongside the system.
    dotfiles = {
      url = "github:eon5942/eonsdotfiles";
      flake = false;
    };

    mango = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, mango, dotfiles, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit self dotfiles; };
      modules = [
        mango.nixosModules.mango
        ./configuration.nix
      ];
    };
  };
}
