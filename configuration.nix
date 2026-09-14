{ config, pkgs, ... }:

let
  dwlPackage = pkgs.writeShellScriptBin "dwl" ''
    export PATH="/run/wrappers/bin:$PATH"
    exec ${((pkgs.dwl.override {
      configH = ./dwl-config.h;
    }).overrideAttrs (old: {
      patches = old.patches or [] ++ [ ./dwl-gaps.patch ];
    }))}/bin/dwl -s "$HOME/.config/dwl/autostart"
  '';

  # areofyl/fetch: animated 3D fetch tool (not yet in stable nixpkgs)
  fetchPackage = pkgs.stdenv.mkDerivation {
    pname = "fetch";
    version = "2.3.0";
    src = pkgs.fetchFromGitHub {
      owner = "areofyl";
      repo = "fetch";
      rev = "b7d69a25afabc4c53d7444f4fc389c78f4763f1e";
      sha256 = "sha256-e9m8cqwbjERLbUl5508JqbOVv64HqAc6UMt8ezr/qcg=";
    };
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall
      install -Dm755 fetch $out/bin/fetch
      runHook postInstall
    '';
    postInstall = ''
      wrapProgram $out/bin/fetch --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.fastfetch pkgs.pciutils ]}
    '';
    meta = {
      description = "Animated 3D fetch tool";
      homepage = "https://github.com/areofyl/fetch";
      license = pkgs.lib.licenses.isc;
      mainProgram = "fetch";
      platforms = pkgs.lib.platforms.unix;
    };
  };

  # RPCS3 AppImage (newer than the nixpkgs 0.0.40 package). The AppImage's
  # zstd squashfs can't be unpacked by unsquashfs, so we extract with the
  # AppImage runtime's own --appimage-extract and wrap it in an FHS env.
  rpcs3AppImage = let
    rpcs3Extracted = pkgs.stdenvNoCC.mkDerivation {
      name = "rpcs3-appimage-extracted";
      src = pkgs.fetchurl {
        url = "https://github.com/RPCS3/rpcs3-binaries-linux/releases/download/build-726cd2d35885fe016a2ec45d8e972abdb6afa62f/rpcs3-v0.0.42-19988-726cd2d3_linux64.AppImage";
        sha256 = "sha256-McCZ+9nBZt/pGstzsUzEuJ1asxc2XYYPLFgWLVcmtm4=";
      };
      sourceRoot = ".";
      unpackPhase = ''
        cp "$src" rpcs3.AppImage
        chmod +x rpcs3.AppImage
      '';
      installPhase = ''
        ./rpcs3.AppImage --appimage-extract
        mkdir -p "$out"
        cp -a AppDir/. "$out/"
      '';
    };
  in pkgs.symlinkJoin {
    name = "rpcs3-appimage";
    paths = [
      (pkgs.appimageTools.wrapAppImage {
        name = "rpcs3";
        src = rpcs3Extracted;
      })
    ];
    postBuild = ''
      mkdir -p "$out/share"
      cp -a "${rpcs3Extracted}/usr/share/applications" "$out/share/"
      cp -a "${rpcs3Extracted}/usr/share/icons" "$out/share/"
    '';
  };
in
{

environment.systemPackages = with pkgs; [
ayugram-desktop
steam
vesktop
spotify
rpcs3AppImage
neovim
wget
curl
git
opencode
nodejs_22
fastfetch
hyfetch
fetchPackage
foot
wofi
yambar
librewolf
grim
slurp
wl-clipboard
swaybg
xdg-desktop-portal-wlr
mako
rofi
waybar
cava
lavat
kitty
matugen
vscode
libxcb-cursor
unzip
unrar
p7zip
kdePackages.dolphin
];

# Iosevka Nerd Font (matches the kitty font from your dotfiles)
fonts.packages = [ pkgs.nerd-fonts.iosevka ];
#1password
 programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    };

# dwl (minimal Wayland compositor). `-s` runs the autostart script after the
# Wayland socket exists; the script bridges dwl's status output to
# ~/.cache/dwltags for yambar's "dwl" module.
programs.dwl = {
  enable = true;
  package = dwlPackage;
};

# mango (full-featured Wayland compositor, dwl-based). Config lives at
# ~/.config/mango/config.conf (from the dotfiles "base" group).
programs.mango.enable = true;

# Minimal TUI login (no KDE/Qt bloat).
services.greetd = {
  enable = true;
  useTextGreeter = true;
  settings = {
    default_session = {
      user = "greeter";
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${dwlPackage}/bin/dwl";
    };
  };
};

# Window Maker (X11). Launch with `startx` from a TTY (Ctrl+Alt+F2, login, startx).
services.xserver = {
  enable = true;
  windowManager.windowmaker.enable = true;
  displayManager.startx.enable = true;
};

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    #jack.enable = true;
    #wireplumber.enable = true;
  };

  # OpenGL + 32-bit GL (Steam's client is 32-bit and needs libGL/GLX,
  # otherwise it aborts with "glXChooseVisual failed").
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."eon" = {
    isNormalUser = true;
    description = "eon";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable flakes + the new CLI, so this config itself builds via `nixos-rebuild --flake`.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Replace sudo with doas (wheel group gets full access).
  security.sudo.enable = false;
  security.doas = {
    enable = true;
    extraRules = [{
      groups = [ "wheel" ];
      keepEnv = true;
      persist = true;
    }];
  };

  system.stateVersion = "26.05"; # Did you read the comment?

}
