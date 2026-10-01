{ inputs, userOpts, systemOpts, ... }@settings:

{ ... }:

{
  imports = [
    # Argument-free modules (services, locket).
    ./default.nix
    (import ./programs { inherit inputs; })
    (import ./styling.nix settings)
  ];
}
