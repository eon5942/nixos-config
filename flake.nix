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

    # dwl Wayland compositor source (hosted on Codeberg, not a flake). Pinned
    # to an exact rev and built from ./dwl-config.h + the local gaps/fair
    # patches. A flake input keeps its commit in flake.lock alongside every
    # other dependency instead of hiding it inside configuration.nix.
    dwl-src = {
      url = "git+https://codeberg.org/dwl/dwl.git?rev=433c325fb2a1d90b36206925fc429e354e248c99";
      flake = false;
    };

    # areofyl/fetch source (animated 3D fetch tool, not yet in nixpkgs).
    # Pinned as a flake input for the same reason as dwl-src.
    fetch-src = {
      url = "github:areofyl/fetch/b7d69a25afabc4c53d7444f4fc389c78f4763f1e";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, agenix, mango, dotfiles, dwl-src, fetch-src, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit self dotfiles dwl-src fetch-src; };
      modules = [
        agenix.nixosModules.default
        mango.nixosModules.mango
        ./configuration.nix
      ];
    };
  };
}
