{ inputs, ... }:

{ config, lib, pkgs, ... }:

with lib;

{
  options = {
    fudo.vr = {
      enable =
        mkEnableOption "VR configuration for user (OpenXR and OpenComposite)";
    };
  };

  config = mkIf config.fudo.vr.enable {
    # OpenXR runtime configuration
    # Points to WiVRn as the active OpenXR runtime
    xdg.configFile."openxr/1/active_runtime.json" = {
      text = builtins.toJSON {
        file_format_version = "1.0.0";
        runtime = {
          name = "wivrn";
          library_path = "${pkgs.wivrn}/lib/libopenxr_wivrn.so";
        };
      };
    };

    # OpenVR paths configuration for OpenComposite
    # CRITICAL: The /lib/opencomposite suffix is required for WiVRn to find it properly
    # See: https://github.com/NixOS/nixpkgs/issues/387590
    xdg.configFile."openvr/openvrpaths.vrpath" = {
      text = builtins.toJSON {
        runtime = [ "${pkgs.opencomposite}/lib/opencomposite" ];
        version = 1;
      };
      # Don't force overwrite - WiVRn temporarily modifies this file during runtime
      # It will restore it after session ends
      force = false;
    };

    # Add OpenComposite and WiVRn dashboard to user packages
    home.packages = with pkgs; [ opencomposite wivrn ];

    # Note: Per-game Steam launch options must be set manually:
    # PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/wivrn/comp_ipc %command%
  };
}
