{
  description = "NixOS configuration for nixos";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Secret management with age. Encrypts files committed to this repo
    # (./secrets) to the recipient keys listed in `age.secrets`.
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # areofyl/fetch source (animated 3D fetch tool, not yet in nixpkgs).
    # Pinned as a flake input so its commit lives in flake.lock instead of
    # hiding inside configuration.nix.
    fetch-src = {
      url = "github:areofyl/fetch/b7d69a25afabc4c53d7444f4fc389c78f4763f1e";
      flake = false;
    };

    # rEFInd-minimal boot theme (github.com/evanpurkhiser/rEFInd-minimal).
    # Pinned as a non-flake input so its exact commit lives in flake.lock;
    # the theme files are copied to the ESP by configuration.nix.
    refind-minimal = {
      url = "github:evanpurkhiser/rEFInd-minimal";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, agenix, mango, dotfiles, fetch-src, refind-minimal, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit self dotfiles fetch-src refind-minimal; };
      modules = [
        agenix.nixosModules.default
        mango.nixosModules.mango
        ./configuration.nix
      ];
    };
  };
}
