# StumpWM Window Manager Configuration
#
# This module provides a complete StumpWM setup for X11 environments.
# StumpWM is an Emacs-inspired tiling window manager written in Common Lisp.
#
# Features:
# - Emacs-friendly keybindings using Super key as prefix
# - Keybindings matching Hyprland where possible
# - Mode-line (status bar) with system information
# - Multiple workspaces (groups in StumpWM terminology)
# - Window placement rules
# - Per-application settings
#
# This module is only active when enabled via programs.stumpwm.enable

{ inputs, ... }:

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.programs.stumpwm;

  # StumpWM configuration file (stumpwmrc)
  stumpwmrc = pkgs.writeText "stumpwmrc" ''
    ;;; StumpWM Configuration
    ;;; Emacs-friendly keybindings with Super key as prefix
    ;;; Keybindings match Hyprland where possible

    (in-package :stumpwm)

    ;;;; Basic Settings

    ;; Set prefix key to Super (Windows/Command key)
    ;; StumpWM traditionally uses C-t, but we'll use s-t (Super-t) to match Emacs-friendly approach
    (set-prefix-key (kbd "s-t"))

    ;; Disable startup message
    (setf *startup-message* nil)

    ;; Set default terminal
    (defvar *terminal* "kitty")

    ;; Set default browser
    (defvar *browser* "firefox")

    ;; Set file manager
    (defvar *file-manager* "thunar")

    ;; Message and input bar settings
    (set-fg-color "#cdd6f4")
    (set-bg-color "#1e1e2e")
    (set-border-color "#89b4fa")
    (set-focus-color "#89b4fa")
    (set-unfocus-color "#313244")
    (set-float-focus-color "#89b4fa")
    (set-float-unfocus-color "#313244")

    (set-msg-border-width 2)
    (setf *message-window-padding* 10)
    (setf *message-window-gravity* :center)
    (setf *input-window-gravity* :center)

    ;; Window border settings
    (setf *window-border-style* :thin)
    (setf *normal-border-width* 2)
    (setf *maxsize-border-width* 2)
    (setf *transient-border-width* 2)

    ;; Mouse focus policy
    (setf *mouse-focus-policy* :click)

    ;; Window placement
    (setf *new-window-preferred-frame* '(:empty :focused))

    ;;;; Mode Line Configuration

    ;; Enable mode line (status bar)
    (setf *mode-line-timeout* 1)
    (setf *mode-line-border-width* 0)
    (setf *mode-line-pad-x* 10)
    (setf *mode-line-pad-y* 2)
    (setf *mode-line-background-color* "#1e1e2e")
    (setf *mode-line-foreground-color* "#cdd6f4")
    (setf *mode-line-border-color* "#89b4fa")

    ;; Mode line format with system info
    (setf *screen-mode-line-format*
          (list "[^B%n^b] %W^> "  ; Group name and window list
                "%d "               ; Date
                "| CPU:%c "         ; CPU usage
                "| Mem:%M "         ; Memory usage
                "| ^[^B%l^b^]"))    ; Time

    ;; Load contrib modules if available
    (let ((cpu-module (probe-file "/run/current-system/sw/share/common-lisp/sbcl/stumpwm-contrib/util/cpu/cpu.asd"))
          (mem-module (probe-file "/run/current-system/sw/share/common-lisp/sbcl/stumpwm-contrib/util/mem/mem.asd")))
      (when cpu-module
        (load-module "cpu"))
      (when mem-module
        (load-module "mem")))

    ;; Enable mode line on all screens
    (enable-mode-line (current-screen) (current-head) t)

    ;;;; Workspace (Group) Configuration

    ;; Create workspaces 1-9
    (when (not (head-groups (current-screen) (current-head)))
      (gnewbg "2")
      (gnewbg "3")
      (gnewbg "4")
      (gnewbg "5")
      (gnewbg "6")
      (gnewbg "7")
      (gnewbg "8")
      (gnewbg "9"))

    ;;;; Helper Functions

    ;; Function to run or raise applications
    (defcommand run-or-raise-terminal () ()
      "Run or raise terminal"
      (run-or-raise *terminal* '(:class "kitty")))

    (defcommand run-or-raise-browser () ()
      "Run or raise browser"
      (run-or-raise *browser* '(:class "Firefox")))

    (defcommand run-or-raise-emacs () ()
      "Run or raise Emacs"
      (run-or-raise "emacsclient -c -a emacs" '(:class "Emacs")))

    ;; Screenshot commands
    (defcommand screenshot-area () ()
      "Take screenshot of selected area"
      (run-shell-command "maim -s ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"))

    (defcommand screenshot-full () ()
      "Take screenshot of full screen"
      (run-shell-command "maim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"))

    ;; Lock screen
    (defcommand lock-screen () ()
      "Lock the screen"
      (run-shell-command "xscreensaver-command -lock"))

    ;;;; Keybindings

    ;; Clear default bindings in *top-map* to avoid conflicts
    (define-key *top-map* (kbd "s-t") nil)

    ;; Application launchers (matching Hyprland)
    (define-key *top-map* (kbd "s-RET") "exec kitty")           ; Terminal
    (define-key *top-map* (kbd "s-d") "exec wofi --show drun")  ; App launcher (matching Hyprland)
    (define-key *top-map* (kbd "s-e") "exec thunar")            ; File manager

    ;; Window management (matching Hyprland)
    (define-key *top-map* (kbd "s-q") "delete-window")          ; Close window
    (define-key *top-map* (kbd "s-Q") "kill-window")            ; Force kill
    (define-key *top-map* (kbd "s-m") "fullscreen")             ; Toggle fullscreen
    (define-key *top-map* (kbd "s-v") "float-this")             ; Toggle floating
    (define-key *top-map* (kbd "s-S-v") "unfloat-this")         ; Unfloat

    ;; Focus navigation with vim keys (matching Hyprland)
    (define-key *top-map* (kbd "s-h") "move-focus left")
    (define-key *top-map* (kbd "s-j") "move-focus down")
    (define-key *top-map* (kbd "s-k") "move-focus up")
    (define-key *top-map* (kbd "s-l") "move-focus right")

    ;; Move windows with vim keys (matching Hyprland)
    (define-key *top-map* (kbd "s-H") "move-window left")
    (define-key *top-map* (kbd "s-J") "move-window down")
    (define-key *top-map* (kbd "s-K") "move-window up")
    (define-key *top-map* (kbd "s-L") "move-window right")

    ;; Alternative: Move with Shift + direction
    (define-key *top-map* (kbd "s-S-h") "move-window left")
    (define-key *top-map* (kbd "s-S-j") "move-window down")
    (define-key *top-map* (kbd "s-S-k") "move-window up")
    (define-key *top-map* (kbd "s-S-l") "move-window right")

    ;; Workspace (group) navigation (matching Hyprland s-1 through s-9)
    (define-key *top-map* (kbd "s-1") "gselect 1")
    (define-key *top-map* (kbd "s-2") "gselect 2")
    (define-key *top-map* (kbd "s-3") "gselect 3")
    (define-key *top-map* (kbd "s-4") "gselect 4")
    (define-key *top-map* (kbd "s-5") "gselect 5")
    (define-key *top-map* (kbd "s-6") "gselect 6")
    (define-key *top-map* (kbd "s-7") "gselect 7")
    (define-key *top-map* (kbd "s-8") "gselect 8")
    (define-key *top-map* (kbd "s-9") "gselect 9")

    ;; Move window to workspace (matching Hyprland s-S-1 through s-S-9)
    (define-key *top-map* (kbd "s-S-1") "gmove 1")
    (define-key *top-map* (kbd "s-S-2") "gmove 2")
    (define-key *top-map* (kbd "s-S-3") "gmove 3")
    (define-key *top-map* (kbd "s-S-4") "gmove 4")
    (define-key *top-map* (kbd "s-S-5") "gmove 5")
    (define-key *top-map* (kbd "s-S-6") "gmove 6")
    (define-key *top-map* (kbd "s-S-7") "gmove 7")
    (define-key *top-map* (kbd "s-S-8") "gmove 8")
    (define-key *top-map* (kbd "s-S-9") "gmove 9")

    ;; Workspace switching (matching Hyprland Tab navigation)
    (define-key *top-map* (kbd "s-TAB") "gnext")
    (define-key *top-map* (kbd "s-S-TAB") "gprev")

    ;; Frame management (StumpWM's tiling splits)
    (define-key *top-map* (kbd "s-s") "hsplit")                 ; Horizontal split
    (define-key *top-map* (kbd "s-S-s") "vsplit")               ; Vertical split
    (define-key *top-map* (kbd "s-r") "remove-split")           ; Remove current frame
    (define-key *top-map* (kbd "s-S-r") "only")                 ; Keep only current frame

    ;; Resize mode (matching Hyprland s-r for resize mode)
    (define-key *top-map* (kbd "s-R") '*resize-map*)

    ;; Screenshots (matching Hyprland)
    (define-key *top-map* (kbd "s-Print") "screenshot-area")
    (define-key *top-map* (kbd "s-S-Print") "screenshot-full")

    ;; System controls
    (define-key *top-map* (kbd "s-C-l") "lock-screen")          ; Lock screen
    (define-key *top-map* (kbd "s-S-q") "quit")                 ; Quit StumpWM (be careful!)
    (define-key *top-map* (kbd "s-S-r") "restart-hard")         ; Restart StumpWM

    ;; Media keys
    (define-key *top-map* (kbd "XF86AudioPlay") "exec playerctl play-pause")
    (define-key *top-map* (kbd "XF86AudioNext") "exec playerctl next")
    (define-key *top-map* (kbd "XF86AudioPrev") "exec playerctl previous")
    (define-key *top-map* (kbd "XF86AudioRaiseVolume") "exec pamixer -i 5")
    (define-key *top-map* (kbd "XF86AudioLowerVolume") "exec pamixer -d 5")
    (define-key *top-map* (kbd "XF86AudioMute") "exec pamixer -t")
    (define-key *top-map* (kbd "XF86MonBrightnessUp") "exec brightnessctl set +5%")
    (define-key *top-map* (kbd "XF86MonBrightnessDown") "exec brightnessctl set 5%-")

    ;; Info and help
    (define-key *top-map* (kbd "s-?") "help")
    (define-key *top-map* (kbd "s-:") "colon")                  ; Run StumpWM command

    ;;;; Window Rules

    ;; Float certain windows
    (define-frame-preference "Default"
      (0 t t :class "Gimp")
      (0 t t :class "feh")
      (0 t t :class "mpv")
      (0 t t :title "Picture-in-Picture"))

    ;;;; Startup Applications
    ${concatMapStringsSep "\n" (cmd: ''(run-shell-command "${cmd}")'')
    cfg.extraAutostart}

    ;; Start compositor for transparency and effects
    (run-shell-command "picom &")

    ;; Start system tray
    (run-shell-command "trayer --edge top --align right --width 5 --transparent true --tint 0x1e1e2e --height 20 &")

    ;; Set wallpaper
    (run-shell-command "feh --bg-scale ~/.config/background &")

    (message "StumpWM configuration loaded!")
  '';

in {
  options.programs.stumpwm = {
    enable = mkEnableOption "StumpWM window manager";

    extraAutostart = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional commands to run on StumpWM startup";
      example = [ "discord" "element-desktop" ];
    };
  };

  config = mkIf cfg.enable {
    # Install StumpWM
    home.packages = with pkgs; [
      stumpwm # Window manager
      sbcl # Common Lisp implementation
      wofi # Application launcher
      maim # Screenshots
      xclip # Clipboard management
      picom # Compositor for transparency/effects
      trayer # System tray
      feh # Image viewer and wallpaper setter
      xscreensaver # Screen locker

      # System control utilities
      pamixer # Audio control
      playerctl # Media player control
      brightnessctl # Brightness control

      # Additional utilities
      xdotool # X11 automation
      xorg.xprop # X11 property viewer
      xorg.xwininfo # X11 window info
    ];

    # StumpWM configuration file
    home.file.".stumpwmrc".source = stumpwmrc;

    # XScreenSaver configuration for locking
    home.file.".xscreensaver".text = ''
      mode:           one
      selected:       0
      timeout:        0:10:00
      cycle:          0:10:00
      lock:           True
      lockTimeout:    0:05:00
      passwdTimeout:  0:00:30
      fade:           True
      unfade:         False
      fadeSeconds:    0:00:03
      fadeTicks:      20
      dpmsEnabled:    True
      dpmsStandby:    0:10:00
      dpmsSuspend:    0:15:00
      dpmsOff:        0:20:00
    '';

    # Picom configuration for transparency and effects
    home.file.".config/picom.conf".text = ''
      # Backend
      backend = "glx";
      glx-no-stencil = true;
      glx-copy-from-front = false;

      # Shadows
      shadow = true;
      shadow-radius = 7;
      shadow-offset-x = -7;
      shadow-offset-y = -7;
      shadow-opacity = 0.7;

      # Fading
      fading = true;
      fade-delta = 4;
      fade-in-step = 0.03;
      fade-out-step = 0.03;

      # Opacity
      inactive-opacity = 0.95;
      active-opacity = 1.0;
      frame-opacity = 1.0;

      # Opacity rules
      opacity-rule = [
        "90:class_g = 'kitty'",
        "90:class_g = 'Alacritty'",
        "95:class_g = 'Emacs'"
      ];

      # Blur (disabled for performance)
      blur-background = false;

      # Window type settings
      wintypes:
      {
        tooltip = { fade = true; shadow = true; opacity = 0.95; focus = true; };
        dock = { shadow = false; };
        dnd = { shadow = false; };
        popup_menu = { opacity = 0.95; };
        dropdown_menu = { opacity = 0.95; };
      };
    '';

    # Set StumpWM as the window manager in X session
    xsession = {
      enable = true;
      windowManager.command = "${pkgs.stumpwm}/bin/stumpwm";
    };
  };
}
