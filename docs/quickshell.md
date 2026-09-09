# Quickshell

[Quickshell](https://quickshell.org) is a QtQuick toolkit for building desktop
shell components — bars, launchers, lockscreens — in QML. This repo ships an
opinionated bar for Wayland sessions as the `programs.quickshell` Home Manager
module.

Currently enabled for `niten` on **system7 only** (`users/niten.nix`,
`hyprlandHosts`). `jazz` is untouched: it is shared, and Jasper uses GNOME
there.

## How it is wired up

Quickshell is a shell *component*, not a compositor — it needs a Wayland
compositor underneath it, and its workspace widget talks to Hyprland
specifically. So enabling it means enabling `programs.hyprland` too.

On system7 that is a **second session**, not a replacement:

- `nixos-config` keeps `fudo.services.desktop.environment = "cosmic"`, so
  COSMIC remains the default session and cosmic-greeter remains the greeter.
- `fudo.services.desktop.extraSessions = [ "hyprland" ]` adds Hyprland to the
  greeter's session picker and installs the Hyprland XDG portal alongside the
  COSMIC one.
- You pick the session at login. If the bar breaks, log out and pick COSMIC.

The bar is started from Hyprland's `exec-once`, not from
`graphical-session.target`. That is deliberate: a target-driven unit would also
start it inside the COSMIC session, and you would get two bars stacked on top
of each other.

## The theme is generated

`Theme.qml` is **not** written by hand. It is produced at build time from
`config.lib.stylix.colors`, so the bar follows `stylix.base16Scheme`
(`modules/styling.nix`) instead of carrying its own palette.

This is the main reason to prefer Quickshell over the existing Waybar setup:
`modules/programs/hyprland.nix` hardcodes Catppuccin Mocha in four places
(Waybar CSS, swaylock, mako, wofi CSS) while Stylix is set to `material-vivid`.
Anything you build here should read from `Theme`, never a literal colour.

Available properties: `bg`, `bgAlt`, `surface`, `muted`, `fg`, `accent`, `ok`,
`warning`, `critical`, `fontSans`, `fontMono`, `barHeight`, `gap`, `radius`.

## Live editing

QML is designed to be edited and reloaded; the Nix store is read-only. The
module resolves this with two modes.

### Frozen (`dev.enable = false`)

`~/.config/quickshell` is a symlink to a store path built from
`modules/programs/quickshell/*.qml` plus the generated theme. Reproducible,
but every tweak needs a `home-manager switch`. This is the right mode once a
config has settled.

### Live (`dev.enable = true`, the current setting for niten)

`~/.config/quickshell` is an out-of-store symlink to
`~/src/quickshell-config`, an ordinary directory you own. It is seeded from the
Nix defaults on first activation and never overwritten afterwards. Quickshell
watches the files and reloads on save, so edits apply immediately — no rebuild,
no restart.

The trade-off is real and worth stating: that directory is now yours, not
Nix's. It is not reproducible, it is not in git unless you put it there, and
`Theme.qml` stops tracking Stylix until you refresh it.

The `fudo-quickshell` helper manages the boundary:

```
fudo-quickshell init      # seed the dev directory (refuses to overwrite)
fudo-quickshell theme     # pull a fresh Theme.qml from the current Stylix scheme
fudo-quickshell diff      # what have I changed vs. the shipped defaults?
fudo-quickshell reset     # throw away local changes, back to defaults (prompts)
fudo-quickshell defaults  # print the store path of the shipped config
fudo-quickshell restart   # systemctl --user restart quickshell
fudo-quickshell log       # journalctl --user -fu quickshell
```

### The intended loop

1. Edit a file in `~/src/quickshell-config`. Save. Watch the bar change.
2. `fudo-quickshell log` in a spare terminal — QML errors go to the journal,
   and a syntax error means the bar silently does not reload.
3. When you like it, `fudo-quickshell diff`, copy the changes back into
   `modules/programs/quickshell/` in this repo, commit, and
   `home-manager switch`.
4. Optionally flip `dev.enable = false` to prove the committed version is what
   you are actually running.

Step 3 is the part that is easy to skip and then regret — the dev directory is
outside version control, and a fresh machine gets the repo's copy, not yours.
Consider making `~/src/quickshell-config` a git checkout of its own.

### Running a second config side by side

`quickshell` (also installed as `qs`) can run a config from an arbitrary path:

```
qs -p ~/experiments/other-shell/shell.qml
```

Useful for trying something drastic without disturbing the running bar. Stop
the service first (`systemctl --user stop quickshell`) if the experiment also
draws a top-anchored panel, or they will overlap.

## What is in the bar

Flat QML, one file per widget, all in the config root so type resolution needs
no imports or `qmldir`:

| File | What it does |
|---|---|
| `shell.qml` | Root; one `Bar` per monitor via `Variants` |
| `Bar.qml` | The layer-shell panel and its layout |
| `Workspaces.qml` | Hyprland workspace pills, filtered to this monitor |
| `ActiveWindow.qml` | Focused window title, elided |
| `Clock.qml` | `SystemClock`, minute precision |
| `Tray.qml` | StatusNotifierItem tray |
| `Volume.qml` | Default PipeWire sink; click to mute |
| `Battery.qml` | UPower; hides itself on desktops (so: invisible on system7) |
| `Theme.qml` | **Generated** from Stylix — do not edit in the repo |

## Deliberately not done yet

The first pass is a bar and nothing else. Quickshell can absorb more of
`modules/programs/hyprland.nix` later, and each of these is a self-contained
next step:

- **Notifications** — `Quickshell.Services.Notifications` replaces mako.
  mako is still running; the bar does not touch notifications.
- **Launcher** — a QML window plus `Quickshell.Io.Process` replaces wofi.
- **Lockscreen** — `WlSessionLock` + `Quickshell.Services.Pam` replaces
  swaylock, and would let `programs.hyprland.lockCommand` point at Quickshell.
- **Tray menus** — right-click currently calls `secondaryActivate()`; a real
  DBusMenu popup needs `QsMenuOpener`.
- **A session/user switcher** — relevant to jazz rather than system7. Quickshell
  cannot switch users itself (it has no logind binding); it would shell out to
  `loginctl activate` for a running session, or ask the display manager for a
  new greeter. Note that greetd — and therefore cosmic-greeter — has no
  fast-user-switching story, so that work belongs on a GDM host.

## Gotchas

- **`Qt5Compat.GraphicalEffects` is not in the closure.** Blur and drop shadows
  need it. Add `extraQmlPackages = [ pkgs.qt6.qt5compat ];`, which wraps
  Quickshell with the module on `QML2_IMPORT_PATH`.
- **A QML error is silent on screen.** The bar keeps showing the last good
  state, or nothing. Always have `fudo-quickshell log` open while editing.
- **`pragma Singleton` files are auto-registered** by Quickshell for the config
  root — that is why `Theme` works with no import. It also means singletons in
  subdirectories need more ceremony, which is why everything here is flat.
- **Multi-monitor is handled by `Variants`**, not by you. Do not instantiate
  `PanelWindow` directly for a specific screen.
