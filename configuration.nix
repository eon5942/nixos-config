{ config, pkgs, ... }:

let
  dwlPackage = pkgs.writeShellScriptBin "dwl" ''
    export PATH="/run/wrappers/bin:$PATH"
    # wlroots 0.18+ dropped WLR_DRM_NO_MODIFIERS (it used to dodge an NVIDIA
    # DRM modifier crash on the PRIME-offloaded output). Now a harmless no-op;
    # left here in case the modifier path regresses on the NVIDIA driver.
    export WLR_DRM_NO_MODIFIERS=1
    exec ${((pkgs.dwl.override {
      configH = ./dwl-config.h;
      wlroots_0_19 = pkgs.wlroots_0_20;
    }).overrideAttrs (old: {
      version = "0.9-dev";
      src = pkgs.fetchFromCodeberg {
        owner = "dwl";
        repo = "dwl";
        rev = "433c325fb2a1d90b36206925fc429e354e248c99";
        hash = "sha256-tnRaKlmIXiBCtaSh1XMy4EaelBzRAr1K0YzDGHWuy58=";
      };
      patches = old.patches or [] ++ [ ./dwl-gaps.patch ./dwl-fair.patch ];
    }))}/bin/dwl -s "$HOME/.config/dwl/autostart"
  '';

  # areofyl/fetch: animated 3D fetch tool (not yet in stable nixpkgs).
  # The Makefile compiles fetch.c -> fetch and installs to PREFIX/bin/fetch,
  # so we just drive `make` (default build/install phases) like upstream's
  # own nix/package.nix.
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
    makeFlags = [ "PREFIX=${pkgs.lib.placeholder "out"}" ];
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

  # Mocktail: Roblox Player AppImage (github.com/komaruworld/mocktail).
  # Wrapped with --appimage-extract-and-run so it runs without FUSE, and ships
  # a .desktop entry + icon so it appears in launchers and handles roblox://
  # URLs.
  mocktailDesktopFile = pkgs.writeText "space.bigrat.mocktail.desktop" ''
    [Desktop Entry]
    Type=Application
    Name=Mocktail
    GenericName=Roblox Player
    Comment=Play Roblox on Linux
    Exec=mocktail %u
    Icon=space.bigrat.mocktail
    StartupWMClass=space.bigrat.mocktail
    Categories=Game;
    Terminal=false
    MimeType=x-scheme-handler/roblox;x-scheme-handler/roblox-player;
  '';
  mocktailIconFile = pkgs.writeText "space.bigrat.mocktail.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="96 96 320 320" fill="none">
      <title>Mocktail</title>
      <path d="M346.019 412.535L98.7423 346.277L165 99L412.277 165.258L346.019 412.535ZM230.378 212L211.743 281.547L281.289 300.182L299.924 230.635L230.378 212Z" fill="white"/>
    </svg>
  '';
  mocktailPackage = pkgs.stdenv.mkDerivation {
    pname = "mocktail";
    version = "1.0.4";
    src = pkgs.fetchurl {
      url = "https://github.com/komaruworld/mocktail/releases/download/1.0.4/Mocktail-1.0.4-x86_64.AppImage";
      sha256 = "1zjfnmn6s641dqz2avqjywxyq85yi2gn1d8b5xnl76w000xckw87";
    };
    dontUnpack = true;
    dontFixup = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/libexec/mocktail.AppImage
      makeWrapper $out/libexec/mocktail.AppImage $out/bin/mocktail \
        --add-flags "--appimage-extract-and-run"
      install -Dm644 ${mocktailDesktopFile} $out/share/applications/space.bigrat.mocktail.desktop
      install -Dm644 ${mocktailIconFile} $out/share/icons/hicolor/scalable/apps/space.bigrat.mocktail.svg
      runHook postInstall
    '';
    meta = with pkgs.lib; {
      description = "Roblox Player for Linux";
      homepage = "https://github.com/komaruworld/mocktail";
      license = licenses.unfree;
      mainProgram = "mocktail";
      platforms = [ "x86_64-linux" ];
    };
  };

  # chres: cycle a monitor through a list of resolutions using wlr-randr
  # (wlroots output-management protocol, supported by dwl/mango). Runs from a
  # keybind or the shell. Usage: chres [output-name] — defaults to the first
  # enabled non-laptop output.
  chres = pkgs.writeShellScriptBin "chres" ''
    set -euo pipefail

    MODES=(1920x1080 2560x1440 3840x2160 1280x720 1366x768)

    output="''${1:-}"
    state="$(wlr-randr --json)"

    if [[ -z "$output" ]]; then
      output="$(printf '%s' "$state" | jq -r '
        [.[] | select((.enabled // "") | tostring == "true")] as $en
        | (($en | map(select((.name // "") | startswith("eDP-") | not))[0]) // $en[0])
        | .name // empty
      ')"
    fi

    [[ -z "$output" ]] && { echo "chres: no enabled output found" >&2; exit 1; }

    cur="$(printf '%s' "$state" | jq -r --arg o "$output" '
      .[] | select(.name == $o)
      | (.modes // []) | map(select((.current // "") | tostring == "true"))[0]
      | "\(.width)x\(.height)"
    ')"

    idx=0
    for i in "''${!MODES[@]}"; do
      [[ "''${MODES[$i]}" == "$cur" ]] && idx=$(( (i + 1) % ''${#MODES[@]} ))
    done

    echo "chres: $output $cur -> ''${MODES[$idx]}"
    wlr-randr --output "$output" --mode "''${MODES[$idx]}"

    # Re-run the monitor layout so the laptop panel is re-placed edge-to-edge
    # with the new resolution (never overlapping).
    if [ -x "$HOME/.local/bin/monitor-layout" ]; then
      "$HOME/.local/bin/monitor-layout"
    fi
  '';

  # Session entries for greetd/tuigreet. Mango is the default compositor;
  # hit F3 at the login prompt to pick dwl instead.
  mangoDesktop = pkgs.writeText "mango.desktop" ''
    [Desktop Entry]
    Name=Mango
    Comment=mango WM
    Exec=${config.programs.mango.package}/bin/mango
    Type=Application
  '';
  dwlDesktop = pkgs.writeText "dwl.desktop" ''
    [Desktop Entry]
    Name=dwl
    Comment=dwl WM
    Exec=${dwlPackage}/bin/dwl
    Type=Application
  '';
  sessionsDir = pkgs.runCommand "greetd-wayland-sessions" { } ''
    mkdir -p "$out"
    cp ${mangoDesktop} "$out/mango.desktop"
    cp ${dwlDesktop} "$out/dwl.desktop"
  '';
in
{

environment.systemPackages = with pkgs; [
ayugram-desktop
steam
vesktop
spotify
rpcs3AppImage
mocktailPackage
neovim
wget
curl
git
# C compiler + tree-sitter CLI so nvim-treesitter can build parser grammars
gcc
tree-sitter
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
yazi
audacity
obs-studio
wireplumber
wlr-randr
wdisplays
brightnessctl
jq
socat
playerctl
swaylock
pavucontrol
qbittorrent
chres
];

# Iosevka Nerd Font (matches the kitty font from your dotfiles)
fonts.packages = [ pkgs.nerd-fonts.iosevka ];
#1password
 programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    };

# Lets dynamically-linked binaries from outside nixpkgs (e.g. Mason-installed
# LSP servers like lua-language-server, rust-analyzer, clangd) find the Linux
# dynamic loader at /lib64/ld-linux-x86-64.so.2 and actually run on NixOS.
programs.nix-ld.enable = true;

# dwl (minimal Wayland compositor). `-s` runs the autostart script after the
# Wayland socket exists; the script bridges dwl's status output to
# ~/.cache/dwltags for yambar's "dwl" module.
programs.dwl = {
  enable = true;
  package = dwlPackage;
};

# mango (full-featured Wayland compositor, dwl-based). Config lives at
# ~/.config/mango/config.conf, deployed from the dotfiles repo (eonsdotfiles)
# by selecting a profile there:
#   dots config use mango   -> old mango rice (matugen/ore waybar)
#   dots config use mono    -> new rice (dwl monochrome look ported onto mango)
# This NixOS module only builds/installs the compositor; it does not manage
# the rice, so nixos-rebuild is identical for both states.
programs.mango.enable = true;

# Minimal TUI login (no KDE/Qt bloat).
services.greetd = {
  enable = true;
  useTextGreeter = true;
  settings = {
    default_session = {
      user = "greeter";
      command = "${pkgs.tuigreet}/bin/tuigreet --time --sessions ${sessionsDir} --cmd ${config.programs.mango.package}/bin/mango";
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

  # Use the default (stable) kernel. `linuxPackages_latest` (Linux 7.x) is too
  # new for the proprietary NVIDIA driver, which fails to compile against it.
  boot.kernelPackages = pkgs.linuxPackages;

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
    wireplumber.enable = true;
  };

  # Screen capture (OBS, screenshots) in dwl via the wlroots desktop portal.
  # mango's own NixOS module configures its portal; this does the same for dwl.
  # GTK stays the fallback so file pickers keep working; only ScreenCast and
  # Screenshot route to the wlr backend.
  #
  # The screencast chooser is set to wofi explicitly: the portal runs as a
  # systemd user service whose PATH does not include wofi/rofi/wmenu, so the
  # built-in dmenu autodetection fails ("no output found") and screen sharing
  # (Vesktop/OBS) breaks. Pointing chooser_cmd at an absolute path fixes it.
  xdg.portal = {
    enable = true;
    wlr = {
      enable = true;
      settings = {
        screencast = {
          chooser_type = "dmenu";
          chooser_cmd = "${pkgs.wofi}/bin/wofi -d -n --prompt='Select a source to share:'";
        };
      };
    };
    config.dwl = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      "org.freedesktop.impl.portal.Inhibit" = [ ];
    };
  };

  # dwl doesn't set XDG_CURRENT_DESKTOP itself (mango sets its own to "mango"),
  # so provide it here so apps launched from dwl route to the config above.
  environment.sessionVariables.XDG_CURRENT_DESKTOP = "dwl";

  # OpenGL + 32-bit GL (Steam's client is 32-bit and needs libGL/GLX,
  # otherwise it aborts with "glXChooseVisual failed").
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # NVIDIA hybrid graphics (RTX 40-series). Nouveau has no working 3D
  # acceleration on Ada Lovelace, which breaks Steam rendering. Use the
  # proprietary driver with PRIME offload: Intel renders the desktop, the
  # NVIDIA GPU is used on demand via `prime-run`.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    powerManagement.enable = true;
    prime = {
      offload.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
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
