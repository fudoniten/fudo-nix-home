{ inputs, ... }:

{ config, lib, pkgs, ... }:

{
  imports = [ (import ./doom-emacs.nix { inherit inputs; }) ];
}
