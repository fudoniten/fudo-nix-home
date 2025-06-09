{ inputs, userOpts, systemOpts, ... }@settings:

{ config, lib, pkgs, ... }:

{
  imports = [ ./services (import ./styling.nix settings) ];
}
