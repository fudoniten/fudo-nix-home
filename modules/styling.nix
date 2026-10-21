{
  inputs,
  userOpts,
  systemOpts,
  ...
}:

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  isGui = systemOpts.desktop.type != "none";
  isLinux = pkgs.stdenv.isLinux;

  scale = config.fudo.displayScale;

  # GNOME only takes an integer scaling-factor without experimental
  # mutter features, so split a fractional scale into an integer display
  # scale plus a text-scaling-factor for the remainder (1.5 -> 1 x 1.5).
  gnomeScale = max 1 (builtins.floor scale);
  gnomeTextScale = scale / gnomeScale;

in
{
  options.fudo.displayScale = mkOption {
    type = types.either types.int types.float;
    default = 2;
    description = ''
      Desktop-wide UI scale. 2 renders text and UI at double density, the
      way macOS does on Retina displays -- much crisper on high-DPI panels,
      but everything is twice as large, so drop to 1.5 or 1.25 (or 1 on
      low-DPI screens) if it's too big. Used as the Hyprland monitor scale
      and the GNOME scaling factor.
    '';
  };

  config = mkIf isGui {
    stylix = {
      imageScalingMode = "fit";

      polarity = "either";

      base16Scheme = mkDefault "${pkgs.base16-schemes}/share/themes/material-vivid.yaml";
    };

    # Read by GNOME, and by GTK apps under other desktops via the settings
    # portal. Matches the system fontconfig defaults: slight hinting,
    # grayscale antialiasing.
    #
    # scaling-factor only seeds mutter's choice for monitors it has no saved
    # layout for: once a scale is picked in Settings -> Displays it lives in
    # ~/.config/monitors.xml and wins over this.
    dconf.settings = mkIf isLinux {
      "org/gnome/desktop/interface" = {
        font-hinting = "slight";
        font-antialiasing = "grayscale";
        scaling-factor = hm.gvariant.mkUint32 gnomeScale;
        text-scaling-factor = gnomeTextScale + 0.0;
      };
    };
  };
}
