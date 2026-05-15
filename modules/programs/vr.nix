{ inputs, ... }:

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.fudo.vr;

  wivrn-config = pkgs.writeText "wivrn-config.json" (builtins.toJSON {
    encoders = [{
      encoder = cfg.wivrn.encoder;
      codec = cfg.wivrn.codec;
      width = 1.0;
      height = 1.0;
      offset_x = 0.0;
      offset_y = 0.0;
    }];
    bitrate = cfg.wivrn.bitrate;
    # WayVR provides the Wayland compositor inside VR; without this, launched
    # apps connect to the desktop compositor and never appear in the headset.
    application = lib.getExe pkgs.wayvr;
  });

  # Helper script to launch apps via wayvrctl
  # This ensures apps render in VR instead of on the host desktop
  wayvrctl-launcher = pkgs.writeShellScriptBin "wayvrctl-launcher" ''
    set -e
    app="$1"
    shift
    # Use wayvrctl process-launch to route the app through WayVR's virtual desktop
    APP_PATH=$(which "$app" 2>/dev/null || echo "$app")
    exec ${lib.getExe pkgs.wayvr}/bin/wayvrctl process-launch "$APP_PATH" "$@"
  '';

in {
  options = {
    fudo.vr = {
      enable =
        mkEnableOption "VR configuration for user (OpenXR and OpenComposite)";

      wivrn = {
        encoder = mkOption {
          type = types.str;
          default = "vulkan";
          description = "WiVRn encoder backend (e.g. vulkan, vaapi, x264)";
        };

        codec = mkOption {
          type = types.str;
          default = "h265";
          description = "WiVRn video codec (e.g. h265, h264, av1)";
        };

        bitrate = mkOption {
          type = types.int;
          default = 50000000;
          description = "WiVRn target bitrate in bits per second";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # OpenXR runtime configuration
    # Points to WiVRn as the active OpenXR runtime
    xdg.configFile."openxr/1/active_runtime.json" = {
      force = true;
      source = "${pkgs.wivrn}/share/openxr/1/openxr_wivrn.json";
    };

    # OpenVR paths configuration for OpenComposite
    # CRITICAL: The /lib/opencomposite suffix is required for WiVRn to find it properly
    # See: https://github.com/NixOS/nixpkgs/issues/387590
    xdg.configFile."openvr/openvrpaths.vrpath" = {
      text = builtins.toJSON {
        runtime = [ "${pkgs.opencomposite}/lib/opencomposite" ];
        version = 1;
      };
      # WiVRn temporarily modifies this file during runtime and restores it after
      force = true;
    };

    home.packages = with pkgs; [
      opencomposite # SteamVR compatibility layer
      wivrn # WiVRn dashboard and tools
      bubblewrap # Container runtime (patched for VR CAP_SYS_NICE)
      wayvr # Access Wayland/X11 desktop from VR
      xrizer # OpenXR-to-OpenVR compatibility layer
      wayvrctl-launcher # Helper script for launching apps in VR
    ];

    # Make WiVRn's OpenXR runtime visible to Steam games via Pressure Vessel
    # Also add Steam environment variables for VR support
    home.sessionVariables = {
      PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES = "1";
      # OpenXR runtime support in Proton/Pressure Vessel
      PRESSURE_VESSEL_FILESYSTEMS_RW = "$XDG_RUNTIME_DIR/wivrn/comp_ipc";
    };

    systemd.user.services.wivrn = {
      Unit = { Description = "WiVRn XR runtime service"; };

      Service = {
        ExecStart = "${lib.getExe pkgs.wivrn} -f ${wivrn-config}";

        Environment = [
          # Standard Monado/WiVRn runtime settings
          "XRT_COMPOSITOR_LOG=debug"
          "XRT_PRINT_OPTIONS=on"
          "IPC_EXIT_ON_DISCONNECT=off"
          # Lighthouse (SteamVR base station) tracking support
          "STEAMVR_LH_ENABLE=1"
          # Use compute compositor for better performance
          "XRT_COMPOSITOR_COMPUTE=1"
          # Allow Steam games to discover WiVRn runtime via Pressure Vessel
          "PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1"
          # Nix profile and system bins so launched apps are found
          "PATH=${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:/run/wrappers/bin:/usr/local/bin:/usr/bin:/bin"
        ];

        # Hardening options (from upstream NixOS module, non-highPriority mode)
        CapabilityBoundingSet = [ "CAP_SYS_NICE" ];
        AmbientCapabilities = [ "CAP_SYS_NICE" ];
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
      };

      Install = { WantedBy = [ "graphical-session.target" ]; };
    };

    # WiVRn discovers apps via .desktop files with X-WiVRn-VR in Categories.
    # These entries make the apps available in the WiVRn application picker,
    # launching them through wayvrctl's process-launch for proper VR routing.
    xdg.desktopEntries = {
      firefox-vr = {
        name = "Firefox (VR)";
        exec = "wayvrctl-launcher firefox";
        icon = "firefox";
        categories = [ "X-WiVRn-VR" ];
      };

      kitty-vr = {
        name = "Kitty (VR)";
        exec = "wayvrctl-launcher kitty";
        icon = "kitty";
        categories = [ "X-WiVRn-VR" ];
      };

      emacs-vr = {
        name = "Emacs (VR)";
        exec = "wayvrctl-launcher emacsclient -- -c";
        icon = "emacs";
        categories = [ "X-WiVRn-VR" ];
      };

      spotify-vr = {
        name = "Spotify (VR)";
        exec = "wayvrctl-launcher spotify";
        icon = "spotify";
        categories = [ "X-WiVRn-VR" ];
      };
    };
  };
}
