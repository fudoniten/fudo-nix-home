{ inputs, userOpts, systemOpts, ... }:

{ config, lib, pkgs, ... }:

with lib;
let isGui = systemOpts.desktop.type != "none";

in mkIf isGui {
  stylix = {
    imageScalingMode = "fit";

    polarity = "either";

    base16Scheme =
      mkDefault "${pkgs.base16-schemes}/share/themes/material-vivid.yaml";
  };
}
