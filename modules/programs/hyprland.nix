# Hyprland Window Manager Configuration
#
# This module provides a complete Hyprland setup for Wayland environments.
# It includes:
# - Hyprland window manager with Emacs-friendly keybindings
# - Waybar status bar with system information
# - Swaylock for screen locking
# - Mako for notifications
# - Grimblast for screenshots
# - Workspace animations and per-app window rules
#
# This module is only active when enabled via programs.hyprland.enable

{ inputs, ... }:

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.programs.hyprland;

  # Waybar configuration
  waybarConfig = {
    layer = "top";
    position = "top";
    height = 30;
    spacing = 4;

    modules-left = [ "hyprland/workspaces" "hyprland/window" ];
    modules-center = [ "clock" ];
    modules-right = [ "tray" "pulseaudio" "network" "cpu" "memory" "battery" ];

    "hyprland/workspaces" = {
      format = "{id}";
      on-click = "activate";
      sort-by-number = true;
    };

    "hyprland/window" = {
      max-length = 50;
      separate-outputs = true;
    };

    clock = {
      format = "{:%a %b %d  %H:%M}";
      tooltip-format = ''
        <big>{:%Y %B}</big>
        <tt><small>{calendar}</small></tt>'';
    };

    cpu = {
      format = " {usage}%";
      tooltip = true;
    };

    memory = {
      format = " {}%";
      tooltip-format = "RAM: {used:0.1f}G / {total:0.1f}G";
    };

    battery = {
      states = {
        warning = 30;
        critical = 15;
      };
      format = "{icon} {capacity}%";
      format-charging = " {capacity}%";
      format-plugged = " {capacity}%";
      format-icons = [ "" "" "" "" "" ];
    };

    network = {
      format-wifi = " {essid}";
      format-ethernet = " {ipaddr}";
      format-disconnected = "⚠ Disconnected";
      tooltip-format = "{ifname}: {ipaddr}/{cidr}";
    };

    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = " Muted";
      format-icons = {
        headphone = "";
        hands-free = "";
        headset = "";
        phone = "";
        portable = "";
        car = "";
        default = [ "" "" "" ];
      };
      on-click = "pamixer -t";
      on-click-right = "pavucontrol";
    };

    tray = { spacing = 10; };
  };

  # Waybar styling
  waybarStyle = ''
    * {
      border: none;
      border-radius: 0;
      font-family: "Iosevka Nerd Font", monospace;
      font-size: 13px;
      min-height: 0;
    }

    window#waybar {
      background-color: rgba(30, 30, 46, 0.9);
      color: #cdd6f4;
    }

    #workspaces button {
      padding: 0 5px;
      color: #cdd6f4;
      background-color: transparent;
      border-bottom: 3px solid transparent;
    }

    #workspaces button.active {
      background-color: rgba(137, 180, 250, 0.2);
      border-bottom: 3px solid #89b4fa;
    }

    #workspaces button.urgent {
      background-color: #f38ba8;
    }

    #workspaces button:hover {
      background-color: rgba(205, 214, 244, 0.1);
    }

    #window {
      padding: 0 10px;
      color: #89b4fa;
    }

    #clock,
    #battery,
    #cpu,
    #memory,
    #network,
    #pulseaudio,
    #tray {
      padding: 0 10px;
      margin: 0 3px;
      background-color: rgba(49, 50, 68, 0.8);
      border-radius: 5px;
    }

    #battery.charging {
      color: #a6e3a1;
    }

    #battery.warning:not(.charging) {
      color: #f9e2af;
    }

    #battery.critical:not(.charging) {
      color: #f38ba8;
    }

    #pulseaudio.muted {
      color: #6c7086;
    }
  '';

in {
  options.programs.hyprland = {
    enable = mkEnableOption "Hyprland window manager";

    extraAutostart = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional commands to run on Hyprland startup";
      example = [ "discord" "element-desktop" ];
    };

    statusBar = mkOption {
      type = types.enum [ "waybar" "none" ];
      default = "waybar";
      description = ''
        Status bar to autostart with the session. Set to "none" when
        something else provides the bar -- fudo.quickshell sets this
        for you when enabled, since two stacked bars is never the intent.

        The Waybar config files are written either way, so flipping this
        back to "waybar" takes effect on the next login with no rebuild.
      '';
    };

    batteryFriendly = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Disable animations, shadows, and enable VRR. Recommended on
        laptops to reduce battery usage.
      '';
    };

    lockCommand = mkOption {
      type = types.str;
      default = "swaylock";
      description = ''
        Command invoked by the manual screen-lock binding
        ($mod CTRL, L) and by hypridle for auto-lock.
      '';
    };

    kbOptions = mkOption {
      type = types.str;
      default = "";
      example = "caps:super";
      description = ''
        XKB options string (comma-separated, as in `setxkbmap -option` /
        `localectl --keymap`), passed straight through to
        `input.kb_options`. Every binding in this module is prefixed with
        `$mod` (= SUPER), so a keyboard with no physical Super key needs
        something remapped to it here -- `"caps:super"` turns Caps Lock
        into Super_L (Mod4), which is the standard fix and doesn't
        collide with Ctrl/Alt-based bindings the way changing `$mod`
        itself to Alt would (Alt is Emacs' Meta, used constantly by
        programs.doom-emacs). If your keyboard has an otherwise-unused
        Menu/Application key, `"menu:super"` does the same without giving
        up Caps Lock.
      '';
    };
  };

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      xwayland.enable = true;
      systemd.enable = true;

      # Every value below (the "$mod"/"$terminal" variables, bind = [...]
      # strings, general/decoration/dwindle attrs, ...) is written in the
      # classic hyprlang *text* config syntax, not Hyprland's native Lua API.
      # HM's two `configType` renderers are not interchangeable: with "lua"
      # (the default for stateVersion >= 26.05, which is what this repo
      # pins), each settings key is emitted as a Lua call named after the
      # key -- so "$fileManager" becomes the literal, invalid Lua source
      # `hl.$fileManager(...)`, since `$` can't start an identifier. That
      # surfaces as `hyprland.lua:5: <name> expected near '$'` the moment
      # Hyprland actually starts, tripping emergency-bind mode. Pin
      # "hyprlang" explicitly, matching the syntax this config is written in.
      configType = "hyprlang";

      settings = {
        # Monitor configuration - auto-detect
        monitor = [ ",preferred,auto,1" ];

        # Environment variables
        env = [
          "XCURSOR_SIZE,16"
          "QT_QPA_PLATFORM,wayland"
          "SDL_VIDEODRIVER,wayland"
          "GDK_BACKEND,wayland,x11"
          "CLUTTER_BACKEND,wayland"
        ];

        # Autostart applications
        exec-once = (optional (cfg.statusBar == "waybar") "waybar") ++ [
          "mako"
          "wl-paste --watch cliphist store"
          "dbus-update-activation-environment --systemd --all"
          "hypridle"
          "hyprpolkitagent"
        ] ++ cfg.extraAutostart;

        # Input configuration
        input = {
          kb_layout = "us";
          kb_options = cfg.kbOptions;
          follow_mouse = 1;
          touchpad = {
            natural_scroll = true;
            disable_while_typing = true;
          };
          sensitivity = 0;
        };

        # General window management
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          "col.active_border" = "rgba(89b4faee) rgba(cba6f7ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";
          layout = "dwindle";
          allow_tearing = false;
          vrr = mkIf cfg.batteryFriendly 1;
        };

        # Decorations
        decoration = {
          rounding = 8;

          shadow = if cfg.batteryFriendly then {
            enabled = false;
          } else {
            enabled = true;
            range = 4;
            render_power = 3;
            color = "rgba(1a1a1aee)";
          };

          blur.enabled = false; # Disabled for performance
        };

        # Animations
        animations = {
          enabled = !cfg.batteryFriendly;
          bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
          animation = [
            "windows, 1, 7, myBezier"
            "windowsOut, 1, 7, default, popin 80%"
            "border, 1, 10, default"
            "borderangle, 1, 8, default"
            "fade, 1, 7, default"
            "workspaces, 1, 6, default"
          ];
        };

        # Dwindle layout settings
        dwindle = {
          pseudotile = true;
          preserve_split = true;
        };

        # Master layout settings (alternative)
        master = { new_status = "master"; };

        # Gestures
        gestures = { workspace_swipe = true; };

        # Miscellaneous settings
        misc = {
          force_default_wallpaper = 0;
          disable_hyprland_logo = true;
        };

        # Variables
        "$mod" = "SUPER";
        "$terminal" = "kitty";
        "$fileManager" = "thunar";
        "$menu" = "wofi --show drun";

        # Keybindings
        bind = [
          # Application launchers
          "$mod, Return, exec, $terminal"
          "$mod, D, exec, $menu"
          "$mod SHIFT, D, exec, wofi --show run"
          "$mod, E, exec, $fileManager"

          # Window management
          "$mod, Q, killactive"
          "$mod, M, fullscreen, 0"
          "$mod, V, togglefloating"
          "$mod, P, pseudo" # dwindle
          "$mod, J, togglesplit" # dwindle

          # Move focus with vim keys
          "$mod, H, movefocus, l"
          "$mod, L, movefocus, r"
          "$mod, K, movefocus, u"
          "$mod, J, movefocus, d"

          # Move windows with vim keys
          "$mod SHIFT, H, movewindow, l"
          "$mod SHIFT, L, movewindow, r"
          "$mod SHIFT, K, movewindow, u"
          "$mod SHIFT, J, movewindow, d"

          # Workspace navigation
          "$mod, 1, workspace, 1"
          "$mod, 2, workspace, 2"
          "$mod, 3, workspace, 3"
          "$mod, 4, workspace, 4"
          "$mod, 5, workspace, 5"
          "$mod, 6, workspace, 6"
          "$mod, 7, workspace, 7"
          "$mod, 8, workspace, 8"
          "$mod, 9, workspace, 9"
          "$mod, 0, workspace, 10"

          # Move window to workspace
          "$mod SHIFT, 1, movetoworkspace, 1"
          "$mod SHIFT, 2, movetoworkspace, 2"
          "$mod SHIFT, 3, movetoworkspace, 3"
          "$mod SHIFT, 4, movetoworkspace, 4"
          "$mod SHIFT, 5, movetoworkspace, 5"
          "$mod SHIFT, 6, movetoworkspace, 6"
          "$mod SHIFT, 7, movetoworkspace, 7"
          "$mod SHIFT, 8, movetoworkspace, 8"
          "$mod SHIFT, 9, movetoworkspace, 9"
          "$mod SHIFT, 0, movetoworkspace, 10"

          # Workspace overview (workspace switcher)
          "$mod, Tab, workspace, previous"
          "$mod SHIFT, Tab, workspace, next"

          # Special workspace (scratchpad-like)
          "$mod, S, togglespecialworkspace, magic"
          "$mod SHIFT, S, movetoworkspace, special:magic"

          # Screenshots
          "$mod, Print, exec, grimblast copy area"
          "$mod SHIFT, Print, exec, grimblast copy screen"

          # Screen lock
          "$mod CTRL, L, exec, ${cfg.lockCommand}"

          # Resize mode (submap)
          "$mod, R, submap, resize"
        ];

        # Mouse bindings
        bindm =
          [ "$mod, mouse:272, movewindow" "$mod, mouse:273, resizewindow" ];

        # Media keys
        bindl = [
          ", XF86AudioPlay, exec, playerctl play-pause"
          ", XF86AudioNext, exec, playerctl next"
          ", XF86AudioPrev, exec, playerctl previous"
        ];

        bindle = [
          ", XF86AudioRaiseVolume, exec, pamixer -i 5"
          ", XF86AudioLowerVolume, exec, pamixer -d 5"
          ", XF86AudioMute, exec, pamixer -t"
          ", XF86MonBrightnessUp, exec, brightnessctl set +5%"
          ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
        ];

        # Window rules
        windowrulev2 = [
          # Float dialogs and preferences
          "float, class:^(.*dialog.*)$"
          "float, class:^(.*Dialog.*)$"
          "float, title:^(.*Preferences.*)$"
          "float, title:^(.*Settings.*)$"

          # Transparency
          "opacity 0.9 0.9, class:^(kitty)$"
          "opacity 0.9 0.9, class:^(Alacritty)$"
          "opacity 0.95 0.95, class:^(Code)$"

          # Picture-in-picture
          "float, title:^(Picture-in-Picture)$"
          "pin, title:^(Picture-in-Picture)$"
          "size 400 225, title:^(Picture-in-Picture)$"

          # Firefox sharing indicator
          "workspace special:silent, title:^(Firefox — Sharing Indicator)$"
          "workspace special:silent, title:^(.* Sharing Indicator)$"

          # Center floating windows
          "center, floating:1"

          # File chooser dialogs
          "float, title:^(Open File)$"
          "float, title:^(Save File)$"
          "float, title:^(Open Folder)$"

          # Authentication dialogs
          "float, class:^(polkit-gnome-authentication-agent-1)$"
          "float, class:^(gcr-prompter)$"
          "float, class:^(hyprpolkitagent)$"
          "center, class:^(hyprpolkitagent)$"
        ];
      };

      # Resize submap, bound via "$mod, R, submap, resize" above.
      #
      # This is `submaps`, a dedicated option -- not a `submap` key stuffed
      # into `settings`. HM's hyprlang renderer repeats a settings key for
      # every element of a list value (that's how the flat `bind = [ ... ]`
      # list above becomes one `bind = ...` line per entry), so a raw
      # `submap = [ "resize" "binde = ..." ... ]` list would have rendered
      # every line prefixed with a stray `submap = `, e.g.
      # `submap = binde = , H, resizeactive, -10 0` -- not the submap
      # declaration hyprlang expects.
      submaps.resize.settings = {
        binde = [
          ", H, resizeactive, -10 0"
          ", L, resizeactive, 10 0"
          ", K, resizeactive, 0 -10"
          ", J, resizeactive, 0 10"
        ];
        bind = [ ", escape, submap, reset" ];
      };
    };

    # Waybar configuration
    home.file.".config/waybar/config".text = builtins.toJSON waybarConfig;
    home.file.".config/waybar/style.css".text = waybarStyle;

    # Swaylock configuration
    programs.swaylock = {
      enable = true;
      settings = {
        color = "1e1e2e";
        font-size = 24;
        indicator-idle-visible = false;
        indicator-radius = 100;
        indicator-thickness = 7;
        line-color = "1e1e2e";
        inside-color = "1e1e2e";
        ring-color = "89b4fa";
        text-color = "cdd6f4";
        show-failed-attempts = true;
      };
    };

    # Wofi launcher styling (Catppuccin Mocha palette)
    home.file.".config/wofi/style.css".source =
      ./hyprland/wofi-style.css;

    # Wofi launcher config
    home.file.".config/wofi/config".source =
      ./hyprland/wofi-config;

    # Hypridle configuration (auto-lock and DPMS-off)
    home.file.".config/hypr/hypridle.conf".source =
      ./hyprland/hypridle.conf;

    # Mako notification daemon
    services.mako = {
      enable = true;
      defaultTimeout = 5000;
      backgroundColor = "#1e1e2e";
      textColor = "#cdd6f4";
      borderColor = "#89b4fa";
      borderRadius = 8;
      borderSize = 2;
      width = 300;
      height = 100;
      padding = "10";
      margin = "10";
      icons = true;
      maxIconSize = 48;
      font = "sans-serif 11";
      anchor = "top-right";
    };

    # Required packages
    home.packages = with pkgs; [
      # Hyprland utilities
      waybar # Status bar
      wofi # Application launcher
      grimblast # Screenshots (wrapper for grim+slurp)
      grim # Screenshot tool
      slurp # Region selector
      wl-clipboard # Clipboard utilities
      cliphist # Clipboard history manager
      swaylock # Screen locker
      mako # Notification daemon
      libnotify # Notification library

      # File manager
      xfce.thunar

      # Display and system control
      wlr-randr # Display configuration
      brightnessctl # Screen brightness control
      pamixer # Audio control
      pavucontrol # PulseAudio volume control GUI
      playerctl # Media player control

      # Idle management and lock screen
      hypridle # Idle daemon (consumes hypridle.conf above)
      hyprlock # Modern screen locker used by hypridle

      # Polkit authentication agent (native to Hyprland)
      hyprpolkitagent # Lets GUI apps prompt for sudo via Wayland

      # Additional utilities
      xdg-utils # XDG utilities for opening files
      wev # Wayland event viewer (useful for debugging keybinds)
    ];

    # XDG desktop portal for screen sharing and file chooser
    # Note: Portal configuration is managed at the system level in nixos-config
    # to avoid conflicts with multiple portal installations.
  };
}
