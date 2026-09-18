# Home Manager modules that take no arguments beyond the standard module ones.
#
# This is the single list: `modules.nix` imports it and adds the modules that
# need flake inputs or the per-user/system settings, and `mkModule.<user>`
# imports it directly.
#
# It used to be two independent lists -- this file (services + locket) and
# modules.nix (services + programs + styling) -- which is how locket came to be
# unreachable on every NixOS host while still looking wired up: the NixOS path
# goes through modules.nix, which never mentioned it.
{ ... }:

{
  imports = [ ./services ./locket ];
}
