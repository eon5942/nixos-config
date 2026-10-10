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

    # telegram-rs: minimal Telegram CLI ("tg") built on TDLib. Not a flake, so
    # it's pulled as a plain source input (flake = false) and built by a local
    # derivation in configuration.nix


  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"
    tgt.url = "github:FedericoBruzzone/tgt";
    tgt.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, agenix, mango, dotfiles, fetch-src, telegram-rs, tgt, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      # tdlib-rs hardcodes TDLib 1.8.61 (its build checks for
      # lib/libtdjson.so.1.8.61). nixpkgs ships 1.8.63, so expose a tdlib dir
      # that symlinks the real lib under the name tdlib-rs expects.
      tdlibLocal = pkgs.stdenv.mkDerivation {
        name = "tdlib-local";
        dontUnpack = true;
        installPhase = ''
          mkdir -p "$out/lib"
          cp -rL ${pkgs.tdlib}/include "$out/include"
          for f in ${pkgs.tdlib}/lib/libtdjson.so*; do
            cp -L "$f" "$out/lib/$(basename "$f")"
          done
          ln -s libtdjson.so "$out/lib/libtdjson.so.1.8.61"
        '';
      };

      # tg: minimal Telegram CLI (github.com/evanpurkhiser/telegram-rs). Its
      # default `download-tdlib` build fetches a libc++-linked prebuilt TDLib at
      # compile time, which won't link on NixOS. Use `local-tdlib` + nixpkgs'
      # source-built `tdlib` instead (libstdc++, properly linked). The build
      # script checks for the hardcoded 1.8.61 soname, hence tdlibLocal above.
      # autoPatchelfHook rewrites the runtime rpath to the real nixpkgs libs.
      telegramRs = pkgs.rustPlatform.buildRustPackage {
        pname = "telegram-rs";
        version = "0.1.1";
        src = telegram-rs;
        cargoHash = "sha256-p7q9ZX949apg5ONkRsmpk8mwahD89+ubdB3Ct9sedrg=";
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = [ tdlibLocal pkgs.tdlib pkgs.openssl pkgs.zlib pkgs.readline ];
        preBuild = ''
          export LOCAL_TDLIB_PATH=${tdlibLocal}
        '';
        postPatch = ''
          substituteInPlace Cargo.toml \
            --replace-fail 'features = ["download-tdlib"]' 'features = ["local-tdlib"]'
        '';
        meta = with pkgs.lib; {
          description = "Minimal Telegram CLI client";
          mainProgram = "tg";
          platforms = [ "x86_64-linux" ];
        };
      };
    in {
      packages.x86_64-linux.tg = telegramRs;

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self dotfiles fetch-src telegramRs tgt; };
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
