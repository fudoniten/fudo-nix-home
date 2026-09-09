{ inputs, ... }:

{ config, lib, pkgs, ... }:

{
  imports = [
    (import ./doom-emacs.nix { inherit inputs; })
    (import ./hyprland.nix { inherit inputs; })
    (import ./quickshell.nix { inherit inputs; })
    (import ./stumpwm.nix { inherit inputs; })
    (import ./vr.nix { inherit inputs; })
  ];
}
