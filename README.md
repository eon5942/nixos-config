# nixos-config

Reproducible NixOS system configuration, managed as a
[flake](https://nixos.wiki/wiki/Flakes). One `git clone` + one rebuild
reproduces the whole machine (packages, services, compositors, user, fonts,
bootloader) down to the exact nixpkgs commit it was built from.

This is intentionally a **separate repo from the dotfiles** — it holds system
configuration, not user config.

## How it's reproducible

- **`flake.nix`** declares the system as a single output
  (`nixosConfigurations.nixos`) built from `./configuration.nix`, plus the
  `mango` compositor input.
- **`flake.lock`** pins every input to an immutable commit: `nixpkgs`
  (`nixos-26.05`, currently `21a67dc470149f337cecafbe965d8d252a390518`),
  `mango` (`mangowm/mango`, whose `nixpkgs` follows ours), `scenefx`,
  `flake-parts`, etc. Rebuilds are byte-for-byte identical until you run
  `nix flake update`.
- **`configuration.nix`** is the whole system: packages, services, users,
  fonts, bootloader, timezone, the `dwl` and `mango` compositors, and
  `doas`/`allowUnfree`.
- **`hardware-configuration.nix`** captures machine-specific bits (btrfs
  subvolumes, disk UUIDs, kernel modules) and is imported by
  `configuration.nix`. Regenerate it on new hardware.
- **`dwl-config.h` + `dwl-gaps.patch`** are local, self-contained sources the
  `dwl` compositor is compiled from — nothing external or mutable.

## Files

| File                         | Purpose                                                         |
| ---------------------------- | --------------------------------------------------------------- |
| `flake.nix`                  | Flake entry point; defines `nixosConfigurations.nixos`          |
| `flake.lock`                 | Pins all inputs to exact commits (do not edit by hand)          |
| `configuration.nix`          | The entire system definition                                     |
| `hardware-configuration.nix` | Auto-generated machine config (disks, firmware, kernel modules) |
| `dwl-config.h`               | dwl compile-time config (patched in at build)                   |
| `dwl-gaps.patch`             | Gaps/smartgaps/togglegaps patch applied to dwl                  |

## What's inside the system

- **Compositors**
  - `dwl` (built from `dwl-config.h` + the gaps patch), launched from
    `greetd` + `tuigreet` (minimal TUI login) via
    `dwl -s ~/.config/dwl/autostart`.
  - `mango` (`mangowm/mango`), a full-featured dwl-based compositor, via its
    upstream flake + `programs.mango` NixOS module. Config lives at
    `~/.config/mango/config.conf` (from the dotfiles).
- **X11 fallback** — Window Maker via `startx`.
- **Sound** — PipeWire (`alsa` + `pulse` compatibility).
- **User** — `eon`, in `wheel` and `networkmanager`.
- **Auth** — `sudo` disabled; `doas` for the `wheel` group.
- **Fonts** — Iosevka Nerd Font (matches the dotfiles).
- **Misc** — `allowUnfree = true`, latest kernel, systemd-boot, timezone
  `America/Los_Angeles`, `stateVersion = "26.05"`.
- **Packages** — neovim, opencode, nodejs, librewolf, foot, wofi, yambar,
  grim/slurp/wl-clipboard, fastfetch/hyfetch, and the mango rice stack:
  `rofi`, `waybar`, `cava`, `lavat`, `kitty`, `mako`, `matugen` — plus steam,
  spotify, vesktop, 1password, and more.

## Setup on a new machine

```sh
git clone git@github.com:eon5942/nixos-config.git ~/nixos-config

# enable flakes once (only needed if nix.conf doesn't already have it)
echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf

# (new hardware only) regenerate the machine-specific config, then commit it
# sudo nixos-generate-config --dir ~/nixos-config

sudo nixos-rebuild switch --flake 'path:/home/eon/nixos-config#nixos'
```

After that first rebuild, flakes are enabled *by the config itself*
(`nix.settings.experimental-features`), so subsequent rebuilds need no
manual `nix.conf` editing.

> On this machine `sudo` is replaced by `doas` — use `doas` instead of `sudo`.

## Daily usage

```sh
cd ~/nixos-config

# rebuild after editing configuration.nix
doas nixos-rebuild switch --flake 'path:/home/eon/nixos-config#nixos'

# check what a rebuild would do without applying it
doas nixos-rebuild dry-build --flake 'path:/home/eon/nixos-config#nixos'

# update all inputs (nixpkgs, mango, ...) to their latest commits
nix flake update && doas nixos-rebuild switch --flake 'path:/home/eon/nixos-config#nixos'

# garbage-collect old system generations
doas nix-collect-garbage -d
```

The `path:` prefix is deliberate — see the ownership gotcha below. `nixos-rebuild`
defaults the `#attr` to the hostname (`nixos`), so `path:/home/eon/nixos-config`
(no `#nixos`) also works.

## Gotchas

- **Rebuilding as root hits a git ownership check.** A bare `--flake
  ~/nixos-config` is resolved as `git+file://`, and git/libgit2 refuses to open
  a repository not owned by the current user — so `doas nixos-rebuild --flake .`
  fails with *"repository path … is not owned by current user"*. Two ways
  around it:
  - Use the `path:` ref (shown above) — it copies the directory straight from
    the filesystem and never touches git, so there is no ownership check.
  - Or trust the directory once: `doas git config --global --add safe.directory
    /home/eon/nixos-config` and then `--flake ~/nixos-config#nixos` works as usual.
- **Flakes only see git-tracked files.** If you add/rename a file and the build
  says it can't find it, `git add` it first. `git status` should be clean before
  rebuilding.
- **`hardware-configuration.nix` is machine-specific.** Commit it for *this*
  machine, but regenerate (`nixos-generate-config`) on genuinely different
  hardware — disk UUIDs, filesystems, and firmware differ.
- **Unfree packages** (steam, spotify, 1password, …) need `allowUnfree = true`
  and come from third-party sources, so they're the least reproducible part of
  the build.
- **`mango` builds from source.** It's not in nixpkgs yet, so the first rebuild
  compiles `mango` + `scenefx` (a wlroots fork) locally — allow some time and
  CPU for that. Subsequent rebuilds reuse the cached result.
- **Secrets are out of scope.** The `eon` user's password is set with `passwd`
  and is not tracked here; use `sops-nix`/`agenix` if you want that declarative
  too.
