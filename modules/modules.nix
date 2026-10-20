{
  inputs,
  userOpts,
  systemOpts,
  ...
}@settings:

{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    inputs.fudo-fonts.homeManagerModules.default
    ./services
    (import ./programs { inherit inputs; })
    (import ./styling.nix settings)
  ];
}
