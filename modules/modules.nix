{ inputs, userOpts, systemOpts, ... }@settings:

{ config, lib, pkgs, ... }:

{
  imports = [
    ./services
    (import ./programs { inherit inputs; })
    (import ./styling.nix settings)
  ];
}
