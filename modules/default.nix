{ config, lib, pkgs, ... }:

{
  imports = [
    (import ./services)
    (import ./programs)
  ];
}
