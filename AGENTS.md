# AGENTS.md — fudo-nix-home

Guidance for AI agents (and humans) working in this repository. Read this first,
then dig into the specific file you need. [`README.md`](./README.md) covers
usage/onboarding in depth and [`LOCKET.md`](./LOCKET.md) documents the secrets
system; this file focuses on *how the code is organized and why*.

## What this repo is

The **Home Manager** layer for the Fudo fleet: per-user environment configs
(packages, dotfiles, desktop setup) plus a handful of custom Home Manager
modules (Doom Emacs, SuperCollider, window managers, and **Locket** secrets).
It can be consumed two ways — as a NixOS module (system-wide integration) or as
a standalone Home Manager module on non-NixOS machines.

Current users: `hermes`, `jasper`, `ken`, `niten`, `openclaw`, `reaper`, `root`,
`xiaoxuan` (one file each in `users/`).

## The three-repo family

| Repo | Role | Namespace |
|------|------|-----------|
| **fudo-nix-home** (here) | Per-user Home Manager configs + custom HM modules | `fudo.home-manager.*` |
| **fudo-nix-lib** | Reusable NixOS infra modules + pure utilities + types | `fudo.*`, `pkgs.lib.*` |
| **nixos-config** | Top-level flake; assembles per-host `nixosConfigurations` | (consumer) |

`nixos-config` consumes this repo as its `home-manager-config` input and turns it
on per host via `fudo.home-manager.enable`. This repo is independent of
`fudo-nix-lib` — it's the *user* layer, not the *system* layer. Keep system-level
concerns out of here; they belong in `fudo-nix-lib` or `nixos-config`.

## Flake outputs (the two consumption modes)

From `flake.nix`:

- `nixosModules.default` (alias `home-configuration`) — imports upstream
  `home-manager.nixosModules.home-manager` plus `module.nix`. This exposes the
  `fudo.home-manager` option namespace for **NixOS system integration**.
- `mkModule.<user>` (e.g. `mkModule.niten`) — a **standalone** Home Manager
  module for use outside NixOS (macOS, non-NixOS Linux). It imports `./modules`
  and the user's `users/<user>.nix`.

So: on NixOS, hosts set `fudo.home-manager.users = [ … ]`; off NixOS, a personal
flake calls `fudo-nix-home.mkModule.<user> { … }`.

## The user-config calling convention

Every `users/<name>.nix` is a **curried function** with this exact shape (see
`users/ken.nix` for the simplest real example):

```nix
inputs:                                   # flake inputs
{ username, email, home-directory, ... }: # per-user identity args
systemCfg:                                # system context (desktop.type, stateVersion)
{ config, lib, pkgs, ... }:               # ordinary HM module args
{
  config = { … };
}
```

Conventions inside a user file:
- Guard GUI packages behind `systemCfg.desktop.type != "none"` (`isGui`).
- `systemCfg.desktop.type` is one of `x` | `wayland` | `darwin` | `none`;
  several users `assert` this early.
- Always set `home.username`, `home.homeDirectory`, `home.stateVersion`.

Adding a user: create `users/<name>.nix` following the shape above, wire an
`mkModule.<name>` export in `flake.nix`, then test (see below). The `module.nix`
NixOS path auto-loads `users/<username>.nix` (overridable via `config-user`).

## Directory map

```
flake.nix          # inputs + outputs (nixosModules.default, mkModule.<user>)
module.nix         # NixOS module: the fudo.home-manager.* option namespace
modules/           # custom Home Manager modules (imported by every user)
├── default.nix / modules.nix   # aggregators
├── locket/        # profile-based secrets (default.nix + options.nix)
├── programs/      # doom-emacs, hyprland, stumpwm, vr
├── services/      # supercollider
└── styling.nix    # stylix theming glue
users/             # one file per user (curried-function convention above)
bin/               # Locket CLI (locket, locket-add, locket-check, …)
secrets/           # Locket-encrypted secrets + profiles/ public keys
docs/              # WM cheatsheets (hyprland, stumpwm)
.githooks/         # pre-commit hook (prevents committing private keys)
run-tests.sh       # local test runner (mirrors CI)
LOCKET.md          # Locket documentation
```

## Locket — the secrets subsystem

Locket is a **profile-based** secrets manager: secrets are age-encrypted to one
or more *profiles* (`default`, `desktop`, `server`, …), and a host decrypts only
the profiles whose keys it holds. Decrypted secrets live in tmpfs and are cleaned
up on logout/reboot. See `LOCKET.md` for the full model.

Working with it:
- CLI lives in `bin/` (`./bin/locket …`). Structure is validated by
  `./bin/locket check` and by CI.
- **Enable the pre-commit hook** before touching `secrets/`:
  `git config core.hooksPath .githooks`. It blocks committing private keys.
- The Nix side is the `locket` HM module (`modules/locket/`); enable per user
  with `locket = { enable = true; profiles = [ … ]; }`.

## Key patterns & conventions

- **User layer only.** Packages, dotfiles, desktop/session config, per-user
  services. Anything system-wide belongs upstream (`fudo-nix-lib` / `nixos-config`).
- **`with lib;`** house style; GUI/desktop features gated on `desktop.type`.
- Custom modules are added under `modules/<category>/` and pulled in via the
  `modules/` aggregators — don't import them ad hoc from user files.
- Keep individual user configs "reasonably simple" (README guidance); deep
  customization belongs in a user's own Doom config or similar external input.

## Testing (this repo actually has CI)

Run the suite before committing:

```bash
./run-tests.sh          # mirrors CI: flake check, statix, deadnix, fmt, module/user validation
```

Individual checks:

```bash
nix flake check
nix run nixpkgs#statix -- check .
nix run nixpkgs#deadnix -- --fail .
nix run nixpkgs#nixpkgs-fmt -- --check .     # add without --check to auto-fix
nix eval .#nixosModules.default
nix eval .#mkModule.<user> --apply 'x: builtins.isFunction x'
nix-instantiate --parse users/<user>.nix
./bin/locket check
```

GitHub Actions runs flake validation, statix, deadnix, format checking, module
+ `mkModule` export validation, user-config loading, and Locket structure
validation on every push/PR. Match those locally to avoid round-trips.

## Branch & release convention

Release branches track the NixOS release (this branch pins nixpkgs
`nixos-26.05` and `home-manager release-26.05`). `nixos-config` pins a matching
release of this flake (`fudo-nix-home/<release>`). Keep the `nixpkgs`,
`home-manager`, and `stylix` inputs on the same release when bumping. Do current
work on the feature branch you were given.

## Gotchas

- Two output paths (`nixosModules.default` vs `mkModule.<user>`) must both keep
  working — a change to the user-file convention affects both. Validate both.
- Don't hand-edit anything under `secrets/` without the pre-commit hook enabled;
  a leaked private key is the failure mode Locket's tooling exists to prevent.
