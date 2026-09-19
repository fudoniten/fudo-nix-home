# TODO

Unimplemented work in this repository.

## Locket

Working: `secrets/<user>/` is scanned into `locket.secrets`, entitlement is by
profile, placements are recorded so cleanup is exact, and the decrypt re-runs
on a switch as well as at login. `locket.enable` is on for `niten`.

Nothing is deployed yet, because nothing has been created. That is a sequence
of commands, not a code change:

```bash
git config core.hooksPath .githooks       # once per clone
./bin/locket profile-create default       # save the printed private key!
./bin/locket add niten <name> --target ".config/…" --profiles default
```

and on each host that should hold the profile:

```bash
./bin/locket-copy-keys <host> default
```

The profile set is the part that is awkward to change later, since it decides
what every secret is encrypted to. `default` -- everything, everywhere,
including work -- is enough to start; add `work`, `server` or per-host
profiles when something actually needs to be excluded.

### Open items

- **No test coverage.** The scan, the entitlement filter and the placement
  record are all untested. `nix flake check` only evaluates the modules. A
  Home Manager VM test that creates a profile, adds a secret and checks it
  lands (and is removed on cleanup) would be the first real test in this repo.
- **Rotation changes the closure.** `source` is a `types.path`, so every
  `.age` a host is entitled to is copied into the store. Rotating one secret
  changes that host's closure and needs a deploy. Aegis solved the same
  problem with `runtimePath`; whether it is worth solving here depends on how
  many secrets there end up being.
- **`locket rekey` is unverified.** It exists, and nothing has ever needed it,
  since there are no profiles to rotate. Exercise it before relying on it.
- **Disaster recovery is undocumented and unimplemented.** A profile's private
  key is the only copy. Losing it loses every secret encrypted to it, with no
  recovery path. At minimum, decide whether an escrow recipient (an offline
  key added to every profile) is wanted -- that decision has to be made
  *before* secrets exist, not after.

## Aegis overlap

Aegis has a user-secrets path of its own; it now works, and the two are
complementary. Aegis is admin-mediated, host-keyed, available at boot, and
reaches only Fudo hosts. Locket is user-keyed, available only while you are
logged in, and reaches work and non-NixOS machines.

The rule, until something forces a better one:

- A secret a **service** needs, or that must exist before you log in → aegis.
- A secret **you** need, and that you want on a work machine too → locket.
- Both systems can place a file in `$HOME`. If they ever name the same path,
  locket wins, because it runs at login and aegis runs at boot. Don't rely on
  that -- pick one owner per secret.

Neither CLI knows about the other. A single front end (`fudo-secret add
--scope fudo|global`) would remove most of the cost of having two, and is
worth doing once both have been used in anger for a while.

## Backlog

- **Package the CLI.** `bin/locket*` uses `nix-shell` shebangs, ~1-2s on first
  run. A `pkgs.locket` derivation would remove that and make the tools
  installable via `home.packages`.
- **`locket-remote`.** Clone the repo, edit a secret, push a branch, open a
  PR, so secrets can be changed from a host without a full checkout.
- **Documentation.** A migration guide from agenix/sops-nix.

## Other future work

*Add non-locket TODOs here as they are identified.*
