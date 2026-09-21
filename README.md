# nixos-config

Reproducible NixOS system configuration, managed as a
[flake](https://nixos.wiki/wiki/Flakes). One `git clone` + one rebuild
reproduces the whole machine (packages, services, compositors, user, fonts,
bootloader) down to the exact nixpkgs commit it was built from.

This is intentionally a **separate repo from the dotfiles** — it holds system
configuration, not user config. The dotfiles repo is still pulled in and *pinned*
as the `dotfiles` flake input (below), so its exact commit is locked alongside
the system.

## How it's reproducible

- **`flake.nix`** declares the system as a single output
  (`nixosConfigurations.nixos`) built from `./configuration.nix`, plus the
  `mango` compositor input, the `dotfiles` repo (a non-flake input, pinned but
  not built), and the `fetch-src` source input (a non-flake git repo built from
  its own Makefile).
- **`flake.lock`** pins every input to an immutable commit: `nixpkgs`
  (`nixos-26.05`, currently `21a67dc470149f337cecafbe965d8d252a390518`),
  `mango` (`mangowm/mango`, whose `nixpkgs` follows ours), `dotfiles`
  (`eon5942/eonsdotfiles`), `fetch-src` (`areofyl/fetch`), `scenefx`,
  `flake-parts`, etc. Rebuilds are byte-for-byte identical until you run
  `nix flake update`.
- **`configuration.nix`** is the whole system: packages, services, users,
  fonts, bootloader, timezone, the `mango` compositor, and
  `doas`/`allowUnfreePredicate`.
- **`dotfiles` pinned** — the `dotfiles` flake input locks the dotfiles commit
  in `flake.lock` and exposes it read-only at `/etc/nixos/dotfiles` (deployment
  stays `dots install` from `~/.local/etc`).
- **`hardware-configuration.nix`** captures machine-specific bits (btrfs
  subvolumes, disk UUIDs, kernel modules) and is imported by
  `configuration.nix`. Regenerate it on new hardware.
- **External source as a flake input** — the `fetch` upstream repo is pinned
  as the non-flake `fetch-src` input (exact rev locked in `flake.lock`), so no
  `fetchFromGitHub` hash hides inside `configuration.nix`.
- **AppImages stay `fetchurl`** — RPCS3 and Mocktail are raw binary release
  artifacts, not git/tarball sources, so they can't be flake inputs; they're
  still hash-pinned (`sha256`) and therefore reproducible.
- **`system.configurationRevision`** stamps the exact config commit into the
  running system, so `nixos-version` reports which revision was built (a dirty
  tree shows `<hash>-dirty`). Build via git (not `path:`) to populate it.
- **`nix.channel.enable = false`** — no mutable `nixos` channel is installed, so
  a bare `nixos-rebuild` (without `--flake`) can't silently build a channel that
  has drifted from `flake.lock`.
- **`hardware.enableRedistributableFirmware = true`** — firmware + Intel
  microcode are pinned into the closure rather than depending on host state.

## Files

| File                         | Purpose                                                         |
| ---------------------------- | --------------------------------------------------------------- |
| `flake.nix`                  | Flake entry point; defines `nixosConfigurations.nixos`          |
| `flake.lock`                 | Pins all inputs to exact commits (do not edit by hand)          |
| `configuration.nix`          | The entire system definition                                     |
| `hardware-configuration.nix` | Auto-generated machine config (disks, firmware, kernel modules) |
| `.gitignore`                 | Ignores local build artifacts (`result`, `.direnv/`, etc.)      |
| `secrets/*.age`              | age-encrypted secrets (agenix), decrypted at activation         |
| `secrets.nix`                | recipient public keys the `agenix -e`/`-r` CLI re-encrypts to   |

## What's inside the system

- **Compositor**
  - `mango` (`mangowm/mango`), a full-featured dwl-based Wayland compositor,
    launched from `greetd` + `tuigreet` (minimal TUI login), via its upstream
    flake + `programs.mango` NixOS module. Config lives at
    `~/.config/mango/config.conf` (from the dotfiles).
- **X11 fallback** — Window Maker via `startx`.
- **Android** — WayDroid, a container-based Android runtime (the Linux
  stand-in for MuMu Player, which is Windows/macOS-only).
- **Sound** — PipeWire (`alsa` + `pulse` compatibility).
- **User** — `eon`, in `wheel` and `networkmanager`.
- **Auth** — `sudo` disabled; `doas` for the `wheel` group.
- **Fonts** — Iosevka Nerd Font (matches the dotfiles).
- **Misc** — `allowUnfreePredicate` (a fixed allowlist, not blanket), default
  stable kernel, systemd-boot, timezone `America/Los_Angeles`, `stateVersion = "26.05"`.
- **Packages** — neovim, opencode, nodejs, librewolf, foot, wofi, yambar,
  grim/slurp/wl-clipboard, fastfetch/hyfetch, and the mango rice stack:
  `rofi`, `waybar`, `cava`, `lavat`, `kitty`, `mako`, `matugen` — plus steam,
  spotify, vesktop, 1password, and more.

## Rice profiles (before / after)

The mango *rice* (how mango looks and is keymapped) does **not** live in this
repo — it's user config, tracked in the
[`eon5942/eonsdotfiles`](https://github.com/eon5942/eonsdotfiles) dotfiles
repo. `nixos-rebuild` builds the compositor and installs the package set
(identical for both rices); the rice itself is switched with `dots`.

| State    | Rice                                   | Command                                            |
| -------- | -------------------------------------- | -------------------------------------------------- |
| **before** | old mango rice (matugen/ore waybar)  | `dots config use mango && dots install`            |
| **after**  | new mango rice (dwl monochrome look) | `dots config use mono  && dots install`            |

The `mono` profile is the "port the dwl rice onto mango" result: square
corners, black/white, 8px gaps, 2px borders, `grid` (fair) default layout,
foot + wofi + mako, and the dwl keymap. The `mango` profile is the original
themed setup. Both build the exact same NixOS system.

So "rebuild before" = checkout/keep the `mango` dotfiles profile; "rebuild
after" = switch the dotfiles profile to `mono`. There is no NixOS-side change
between the two states — `nixos-rebuild switch --flake .#nixos` is a no-op
either way.

## Setup on a new machine

```sh
git clone git@github.com:eon5942/nixos-config.git ~/nixos-config

# enable flakes once (only needed if nix.conf doesn't already have it)
echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf

# (new hardware only) regenerate hardware-configuration.nix, then commit it
# (see "Regenerating hardware-configuration.nix" below — don't point --dir
#  straight at the repo, it would overwrite configuration.nix)

# (once) let root's git/libgit2 open this repo
sudo git config --global --add safe.directory /home/eon/nixos-config

sudo nixos-rebuild switch --flake '/home/eon/nixos-config#nixos'
```

After that first rebuild, flakes are enabled *by the config itself*
(`nix.settings.experimental-features`), so subsequent rebuilds need no
manual `nix.conf` editing.

> On this machine `sudo` is replaced by `doas` — use `doas` instead of `sudo`.

## Daily usage

```sh
cd ~/nixos-config

# rebuild after editing configuration.nix
doas nixos-rebuild switch --flake '/home/eon/nixos-config#nixos'

# check what a rebuild would do without applying it
doas nixos-rebuild dry-build --flake '/home/eon/nixos-config#nixos'

# update all inputs (nixpkgs, mango, ...) to their latest commits
nix flake update && doas nixos-rebuild switch --flake '/home/eon/nixos-config#nixos'

# garbage-collect old system generations
doas nix-collect-garbage -d
```

The bare path (no `path:` prefix) is deliberate: nix resolves it as
`git+file://`, so only *committed* files are built and
`system.configurationRevision` is stamped into the system (see the ownership
note below).

## WayDroid (Android on Linux)

WayDroid runs a full Android system in an LXC container on the host kernel (via
the in-kernel `binder`), so there's no CPU emulation — it runs near-native
speed. Enabled with `virtualisation.waydroid.enable`.

```sh
# once: fetch the Android system/vendor image (~1GB, needs root)
doas waydroid init -s GAPPS

# start Android and show its UI
waydroid session start
waydroid show-full-ui
```

> The Android images are downloaded by `waydroid init` at runtime from
> WayDroid's mirrors — they're not packaged by nixpkgs, so they're the one part
> of this setup that isn't pinned in `flake.lock`.

## Regenerating `hardware-configuration.nix`

`hardware-configuration.nix` is machine-specific (disk UUIDs, btrfs subvolumes,
kernel modules, firmware) and is normally written once. Regenerate it when the
hardware or disk layout changes — new drive, repartitioned disk, different
laptop, etc.

`nixos-generate-config` writes **both** `configuration.nix` and
`hardware-configuration.nix` to a directory and **overwrites** whatever is
already there, so never point `--dir` straight at this repo (it would replace
your hand-written `configuration.nix` with an auto-generated skeleton). Use one
of these instead:

**A. Print just the hardware file and redirect it** (preferred — leaves
`configuration.nix` untouched):

```sh
sudo nixos-generate-config --show-hardware-config > ~/nixos-config/hardware-configuration.nix
```

**B. Generate to a temp dir and copy the one file over:**

```sh
sudo nixos-generate-config --dir /tmp/nixos-gen
cp /tmp/nixos-gen/hardware-configuration.nix ~/nixos-config/
```

Then review the diff and rebuild:

```sh
cd ~/nixos-config
git diff hardware-configuration.nix
doas nixos-rebuild switch --flake '/home/eon/nixos-config#nixos'
git add hardware-configuration.nix && git commit -m "hardware: regenerate hardware-configuration.nix"
```

## Gotchas

- **Rebuilding as root hits a git ownership check.** A bare `--flake
  ~/nixos-config` is resolved as `git+file://`, and git/libgit2 refuses to open
  a repository not owned by the current user — so `doas nixos-rebuild --flake .`
  fails with *"repository path … is not owned by current user"*. Fix it once:

  ```sh
  doas git config --global --add safe.directory /home/eon/nixos-config
  ```

  If you'd rather not trust the directory for root, use the `path:` ref instead
  (`--flake 'path:/home/eon/nixos-config#nixos'`) — it copies the directory
  straight from the filesystem and never touches git. The trade-off is that
  `path:` builds *untracked* files too and leaves `configurationRevision` unset.
- **Flakes only see git-tracked files.** If you add/rename a file and the build
  says it can't find it, `git add` it first. `git status` should be clean before
  rebuilding.
- **`.gitignore` keeps the tree clean.** `nix build` / `nix develop` drop a
  `result` symlink and direnv drops `.direnv/`; `.gitignore` hides these so
  `git status` only ever shows real changes. Don't ignore anything the flake
  actually needs to build — ignoring a file means `nixos-rebuild --flake` won't
  see it either.
- **`hardware-configuration.nix` is machine-specific.** Commit it for *this*
  machine, but regenerate (`nixos-generate-config`) on genuinely different
  hardware — disk UUIDs, filesystems, and firmware differ.
- **Unfree packages** (steam, spotify, 1password, vscode, the NVIDIA driver, …)
  come from third-party sources, so they're the least reproducible part of the
  build. They're allowed via an explicit `allowUnfreePredicate` allowlist rather
  than `allowUnfree = true`, so a new unfree dependency fails the build instead
  of being silently accepted.
- **`mango` builds from source.** It's not in nixpkgs yet, so the first rebuild
  compiles `mango` + `scenefx` (a wlroots fork) locally — allow some time and
  CPU for that. Subsequent rebuilds reuse the cached result.
- **Secrets via agenix.** The `eon` password hash is encrypted at rest in
  `secrets/eon-password.age` (age, recipient = eon's SSH key) and decrypted to
  `/run/agenix/eon-password` at activation, where
  `users.users.eon.hashedPasswordFile` reads it. To change it, from the repo
  root (`secrets.nix` supplies the recipients):
  ```sh
  cd ~/nixos-config
  nix run github:ryantm/agenix -- -i ~/.ssh/id_ed25519 -e secrets/eon-password.age
  ```
  The hash is committed encrypted and never stored in plaintext — pick a real
  password for anything that matters.
