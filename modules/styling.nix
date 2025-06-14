{ inputs, userOpts, systemOpts, ... }:

{ config, lib, pkgs, ... }:

with lib;
let isGui = systemOpts.desktop.type != "none";

in mkIf isGui {
  stylix = {
    imageScalingMode = "fit";

    cursor = mkForce {
      package = pkgs.graphite-cursors;
      name = "graphite-dark";
      size = 16;
    };

    opacity = {
      applications = 1.0;
      desktop = 1.0;
      popups = 1.0;
      terminal = 0.9;
    };

    polarity = "either";

    base16Scheme =
      mkDefault "${pkgs.base16-schemes}/share/themes/material-vivid.yaml";

    fonts = with pkgs; {
      serif = mkDefault {
        package = liberation_ttf;
        name = "Liberation Serif";
      };
      sansSerif = mkDefault {
        # package = nerdfonts;
        # name = "SourceSans3VF";
        package = oxanium;
        name = "Oxanium";
      };
      monospace = mkDefault {
        package = nerdfonts;
        name = "Iosevka Nerd Font";
        # name = "Hurmit Nerd Font Mono";
      };
      emoji = mkDefault {
        package = noto-fonts-emoji;
        name = "Noto Color Emoji";
      };
    };
  };
}
