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

    # Add VR-related packages to user environment
    home.packages = with pkgs; [
      opencomposite # SteamVR compatibility layer
      wivrn # WiVRn dashboard and tools
      bubblewrap # Container runtime (patched for VR CAP_SYS_NICE)
      wayvr # Access Wayland/X11 desktop from VR
    ];

    # WiVRn discovers apps via .desktop files with X-WiVRn-VR in Categories.
    # These entries make the apps available in the WiVRn application picker,
    # launching them into WayVR's virtual desktop environment.
    xdg.desktopEntries = {
      firefox-vr = {
        name = "Firefox (VR)";
        exec = "firefox %U";
        icon = "firefox";
        categories = [ "X-WiVRn-VR" ];
      };

      kitty-vr = {
        name = "Kitty (VR)";
        exec = "kitty";
        icon = "kitty";
        categories = [ "X-WiVRn-VR" ];
      };

      emacs-vr = {
        name = "Emacs (VR)";
        exec = "emacsclient -c %F";
        icon = "emacs";
        categories = [ "X-WiVRn-VR" ];
      };

      spotify-vr = {
        name = "Spotify (VR)";
        exec = "spotify %U";
        icon = "spotify";
        categories = [ "X-WiVRn-VR" ];
      };
    };

    # Note: Per-game Steam launch options must be set manually:
    # PRESSURE_VESSEL_FILESYSTEMS_RW=$XDG_RUNTIME_DIR/wivrn/comp_ipc %command%
  };
}
