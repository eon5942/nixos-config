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

    # Ryubing (Ryujinx community fork, Nintendo Switch emulator). The upstream
    # repo (git.ryujinx.app) has no flake.nix, so it is pinned source-only and
    # pkgs.ryubing is overridden to build from this exact commit. Bump the rev
    # and regenerate the nuget deps.json when updating.
    ryubing = {
      url = "git+https://git.ryujinx.app/projects/Ryubing.git?rev=e2143d43bcb6762340d8a01f20e7b5fdf104f02f";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, agenix, mango, dotfiles, fetch-src, ryubing, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit self dotfiles fetch-src ryubing; };
      modules = [
        agenix.nixosModules.default
        mango.nixosModules.mango
        ./configuration.nix
      ];
    };
  };
}
