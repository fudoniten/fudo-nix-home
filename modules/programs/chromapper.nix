{ inputs, ... }:

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.fudo.chromapper;

  # Must match the package wrapper's default working directory, which is
  # where ChroMapper looks for ./Plugins.
  homeDir = "ChroMapper";

in
{
  options = {
    fudo.chromapper = {
      enable = mkEnableOption "ChroMapper, the Beat Saber map editor";

      package = mkOption {
        type = types.package;
        default = inputs.fudo-pkgs.packages.${pkgs.stdenv.hostPlatform.system}.chromapper;
        defaultText = literalExpression "inputs.fudo-pkgs.packages.\${pkgs.stdenv.hostPlatform.system}.chromapper";
        description = "ChroMapper package to install.";
      };

      plugins = mkOption {
        type = types.attrsOf types.path;
        default = { };
        example = literalExpression ''
          {
            "ErrorChecker.dll" = pkgs.fetchurl {
              url = "https://github.com/Top-Cat/CM-ErrorChecker/releases/download/.../ErrorChecker.dll";
              hash = "...";
            };
          }
        '';
        description = ''
          ChroMapper plugins to install, as file name to plugin DLL. They are
          linked into $XDG_DATA_HOME/ChroMapper/Plugins, alongside any plugins
          dropped there by hand.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux && pkgs.stdenv.hostPlatform.isx86_64;
        message = "fudo.chromapper is only packaged for x86_64-linux.";
      }
    ];

    home.packages = [ cfg.package ];

    xdg.dataFile = mapAttrs' (
      name: src: nameValuePair "${homeDir}/Plugins/${name}" { source = src; }
    ) cfg.plugins;
  };
}
