{ config, lib, pkgs, self, dotfiles, fetch-src, ... }:

let
  # areofyl/fetch: animated 3D fetch tool (not yet in stable nixpkgs).
  # Source is pinned via the `fetch-src` flake input (see flake.nix). The
  # Makefile compiles fetch.c -> fetch and installs to PREFIX/bin/fetch, so we
  # just drive `make` (default build/install phases) like upstream's nix/package.nix.
  fetchPackage = pkgs.stdenv.mkDerivation {
    pname = "fetch";
    version = "2.3.0";
    src = fetch-src;
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

  # Steam wrapped to always run on the NVIDIA dGPU (same env as `nvidia-offload`).
  # The bundled Chromium (new Steam UI) otherwise probes the NVIDIA GPU through
  # Mesa GLX, segfaults ("failed to load driver: nvidia-drm"), and falls back to
  # software rendering, which makes the client feel sluggish. Wrapping the binary
  # means the app-launcher .desktop entry (`Exec=steam %U`) picks it up unchanged.
  steamNvidia = pkgs.symlinkJoin {
    name = "steam-nvidia";
    paths = [ pkgs.steam ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/steam" \
        --set __NV_PRIME_RENDER_OFFLOAD 1 \
        --set __NV_PRIME_RENDER_OFFLOAD_PROVIDER NVIDIA-G0 \
        --set __GLX_VENDOR_LIBRARY_NAME nvidia \
        --set __VK_LAYER_NV_optimus NVIDIA_only
    '';
  };

  # chres: cycle a monitor through a list of resolutions using wlr-randr
  # (wlroots output-management protocol, supported by mango). Runs from a
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

  # Session entry for greetd/tuigreet. Mango is the only (default) compositor.
  mangoDesktop = pkgs.writeText "mango.desktop" ''
    [Desktop Entry]
    Name=Mango
    Comment=mango WM
    Exec=${config.programs.mango.package}/bin/mango
    Type=Application
  '';
  sessionsDir = pkgs.runCommand "greetd-wayland-sessions" { } ''
    mkdir -p "$out"
    cp ${mangoDesktop} "$out/mango.desktop"
  '';
in
{

environment.systemPackages = with pkgs; [
ayugram-desktop
steamNvidia
wineWow64Packages.full
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
# Rust toolchain
cargo
rustc
clippy
# Formatters for conform.nvim (format-on-save in neovim)
stylua
black
rustfmt
clang-tools
shfmt
nixfmt
prettier
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
cmatrix
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
efibootmgr
jq
socat
playerctl
python3
swaylock
pavucontrol
qbittorrent
chres
];

# Iosevka Nerd Font (matches the kitty font from your dotfiles)
fonts.packages = [ pkgs.nerd-fonts.iosevka ];
# 1password
programs._1password.enable = true;
programs._1password-gui = {
  enable = true;
};

# Lets dynamically-linked binaries from outside nixpkgs (e.g. Mason-installed
# LSP servers like lua-language-server, rust-analyzer, clangd) find the Linux
# dynamic loader at /lib64/ld-linux-x86-64.so.2 and actually run on NixOS.
programs.nix-ld.enable = true;

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
  # Only keep the 10 most recent generations in the boot menu so it stays
  # tidy (and the ESP doesn't fill up with old kernels).
  boot.loader.systemd-boot.configurationLimit = 10;

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

  # Screen capture (OBS, screenshots) via the wlroots desktop portal. mango's
  # own NixOS module configures its portal; the wlr backend here handles
  # ScreenCast/Screenshot. GTK stays the fallback so file pickers keep working.
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
  };

  # Do NOT set WLR_DRM_DEVICES to list the NVIDIA card first. Making the dGPU
  # the primary DRM device makes wlroots (mango) fail with
  # "couldn't create backend" at boot, because the NVIDIA card has no connector
  # wired to the panel and can't initialise as primary renderer. Leave it unset
  # so wlroots auto-probes: Intel (boot GPU) is primary and drives eDP, NVIDIA
  # is secondary and drives HDMI directly.
  #
  # For Steam/Proton games that need the dGPU, use the PRIME offload wrapper
  # (configured below) instead of forcing the compositor onto NVIDIA:
  #   nvidia-offload %command%
  # This sets __NV_PRIME_RENDER_OFFLOAD=1 + __GLX_VENDOR_LIBRARY_NAME=nvidia,
  # which fixes "failed to load driver: nvidia-drm" without breaking the WM.

  # Include redistributable firmware + Intel CPU microcode in the closure so a
  # rebuild from the flake yields the same firmware set regardless of the host's
  # local firmware state (also enables intel microcode updates, which
  # hardware-configuration.nix ties to this flag).
  hardware.enableRedistributableFirmware = true;

  # OpenGL + 32-bit GL (Steam's client is 32-bit and needs libGL/GLX,
  # otherwise it aborts with "glXChooseVisual failed").
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # NVIDIA hybrid graphics (RTX 40-series). Nouveau has no working 3D
  # acceleration on Ada Lovelace, which breaks Steam rendering. Use the
  # proprietary driver with PRIME offload: Intel renders the desktop, the
  # NVIDIA GPU is used on demand via `nvidia-offload`.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    powerManagement.enable = true;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Xwayland (launched by wlroots for mango) auto-detects the NVIDIA GPU but
  # falls back to the "modesetting" driver (Mesa zink), which breaks NVIDIA PRIME
  # render offload for GLX games ("glx: failed to create dri3 screen" /
  # "failed to load driver: nvidia-drm"). This OutputClass makes Xwayland load the
  # proprietary "nvidia" driver for the dGPU, so `nvidia-offload %command%`
  # (__NV_PRIME_RENDER_OFFLOAD=1) works for Steam/Proton.
  environment.etc."X11/xorg.conf.d/10-nvidia-offload.conf".text = ''
    Section "OutputClass"
      Identifier "nvidia"
      MatchDriver "nvidia-drm"
      Driver "nvidia"
      Option "AllowEmptyInitialConfiguration"
      ModulePath "${config.hardware.nvidia.package.bin}/lib/xorg/modules"
    EndSection
  '';

  # Define a user account (password set declaratively via agenix below).
  users.users."eon" = {
    isNormalUser = true;
    description = "eon";
    extraGroups = [ "networkmanager" "wheel" ];
    hashedPasswordFile = config.age.secrets."eon-password".path;
  };

  # Decrypt committed age secrets (./secrets/*.age) at activation. The machine
  # has no SSH host key (sshd is off), so use eon's own ed25519 key to decrypt;
  # the same public key is the recipient that `secrets/eon-password.age` was
  # encrypted to (see secrets.nix). To change the password, run from the repo
  # root:
  #   nix run github:ryantm/agenix -- -i ~/.ssh/id_ed25519 -e secrets/eon-password.age
  age.identityPaths = [ "/home/eon/.ssh/id_ed25519" ];
  age.secrets."eon-password".file = ./secrets/eon-password.age;

  # Allow only the specific unfree packages this system needs, instead of
  # blanket `allowUnfree = true`, so a new unfree dependency is caught at build
  # time rather than silently accepted.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "steam"           # client + Proton
    "steam-unwrapped" # the unfree client payload behind `steam`
    "spotify"
    "vscode"
    "unrar"
    "nvidia-x11"            # proprietary NVIDIA driver (hardware.nvidia)
    "nvidia-settings"       # NVIDIA control panel (hardware.nvidia.nvidiaSettings)
    "nvidia-kernel-modules" # driver kernel modules
    "nvidia-firmware"       # GSP firmware
    "1password"     # _1password-gui
    "1password-cli" # _1password-cli
    "mocktail"      # Roblox client (local derivation)
  ];

  # Enable flakes + the new CLI, so this config itself builds via `nixos-rebuild --flake`.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Do not install a mutable `nixos` channel. Every input comes from flake.lock;
  # a channel could drift independently of the lock and silently change what a
  # bare `nixos-rebuild` (without `--flake`) would build.
  nix.channel.enable = false;

  # The dotfiles repo (github:eon5942/eonsdotfiles) is pinned as the `dotfiles`
  # flake input (see flake.nix) and passed here via specialArgs, so its exact
  # commit lives in flake.lock. The pinned source is exposed read-only at
  # /etc/nixos/dotfiles for reference. Deployment stays `dots install` from
  # ~/.local/etc — the `dots` tool reads that fixed source path, so the working
  # copy there remains the editable source of truth.
  environment.etc."nixos/dotfiles".source = dotfiles;

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

  # Stamp the exact config commit into the built system, so `nixos-version`
  # reports which revision it was built from (empty/`unset` when built via the
  # `path:` flake ref instead of git). A clean checkout -> full hash; a dirty
  # tree -> `<hash>-dirty`, so you can tell at a glance whether uncommitted
  # changes are in the running system.
  system.configurationRevision =
    self.rev or self.dirtyRev or self.shortRev or self.dirtyShortRev or "unset";

  system.stateVersion = "26.05"; # Did you read the comment?

}
