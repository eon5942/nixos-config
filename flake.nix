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

    # tgt: Telegram TUI (github.com/FedericoBruzzone/tgt). A flake exposing
    # packages.<system>.default, built against our pinned nixpkgs.
    tgt = {
      url = "github:FedericoBruzzone/tgt";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, agenix, mango, dotfiles, fetch-src, tgt, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      # tgt pins tdlib 1.8.29, whose CMakeLists requires cmake <3.5, but
      # nixos-26.05 ships cmake 4.x which dropped that. Inject the
      # compatibility flag into tgt's tdlib so it still configures.
      tgtFixed = tgt.packages.x86_64-linux.default.overrideAttrs (old: let
        tdlibFixed =
          (builtins.head
            (builtins.filter (d: d.pname or "" == "tdlib") old.buildInputs))
          .overrideAttrs (o: {
            cmakeFlags = (o.cmakeFlags or [ ]) ++ [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
          });
        fix = d: if d.pname or "" == "tdlib" then tdlibFixed else d;
      in {
        nativeBuildInputs = map fix old.nativeBuildInputs;
        buildInputs = map fix old.buildInputs;
        env = (old.env or { }) // {
          RUSTFLAGS = "-C link-arg=-Wl,-rpath,${tdlibFixed}/lib -L ${pkgs.openssl}/lib";
          LOCAL_TDLIB_PATH = "${tdlibFixed}/lib";
        };
      });
    in {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self dotfiles fetch-src tgtFixed; };
        modules = [
          agenix.nixosModules.default
          mango.nixosModules.mango
          ./configuration.nix
        ];
      };

      # ThinkPad T480 — lean host, no mango/agenix for now.
      nixosConfigurations.t480 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self dotfiles fetch-src; };
        modules = [ ./t480.nix ];
      };
    };
}
