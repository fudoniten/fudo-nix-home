# Checks the gate on modules/programs/opencode.nix: the OpenCode config is
# installed only when the NixOS host runs Aegis live for the user and is on
# Nebula, and never in the standalone (work-home) path.
#
#   nix eval --impure --json --expr \
#     'import ./tests/opencode.nix { flake = builtins.getFlake (toString ./.); }'
#
# Evaluates to { pass = true; ... } or throws naming the failed case.
{ flake }:

let
  inherit (flake.inputs) nixpkgs home-manager;
  inherit (nixpkgs) lib;

  stateVersion = "26.05";

  # Stands in for aegis.nixosModules.secrets: just the options the gate reads.
  aegisStub =
    { lib, ... }:
    {
      options.aegis.secrets = with lib; {
        enable = mkOption { default = false; };
        dryRun = mkOption { default = false; };
        exportUserEnv = mkOption { default = true; };
        users = mkOption { default = [ ]; };
      };
    };

  hmNiten =
    {
      aegis ? null,
      nebula ? false,
      withAegisModule ? true,
    }:
    (lib.nixosSystem {
      modules = [
        flake.nixosModules.default
        (
          { lib, ... }:
          {
            imports = lib.optional withAegisModule aegisStub;
            config = lib.mkMerge [
              {
                nixpkgs = {
                  hostPlatform = "x86_64-linux";
                  config.allowUnfree = true;
                };
                system.stateVersion = stateVersion;
                boot.loader.grub.device = "nodev";
                fileSystems."/" = {
                  device = "/dev/sda1";
                  fsType = "ext4";
                };
                users.users.niten.isNormalUser = true;
                fudo.home-manager = {
                  enable = true;
                  users = [
                    {
                      username = "niten";
                      email = "niten@example.com";
                      home-directory = "/home/niten";
                    }
                  ];
                  system = {
                    desktop.type = "none";
                    inherit stateVersion;
                  };
                };
                services.nebula.networks.fudo = lib.mkIf nebula {
                  enable = true;
                  ca = "/dev/null";
                  cert = "/dev/null";
                  key = "/dev/null";
                };
              }
              (lib.optionalAttrs (aegis != null) { aegis.secrets = aegis; })
            ];
          }
        )
      ];
    }).config.home-manager.users.niten;

  standaloneNiten =
    (home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      modules = [
        (flake.mkModule.niten {
          username = "niten";
          email = "niten@example.com";
          home-directory = "/home/niten";
          inherit stateVersion;
        })
      ];
    }).config;

  installed = hm: hm.xdg.configFile ? "opencode/opencode.json";

  liveAegis = {
    enable = true;
    users = [ "niten" ];
  };

  full = hmNiten {
    aegis = liveAegis;
    nebula = true;
  };

  cases = {
    "aegis + nebula installs" = installed full;
    "no nebula skips" =
      !installed (hmNiten {
        aegis = liveAegis;
      });
    "dry-run aegis skips" =
      !installed (hmNiten {
        aegis = liveAegis // {
          dryRun = true;
        };
        nebula = true;
      });
    "user not decrypted skips" =
      !installed (hmNiten {
        aegis = liveAegis // {
          users = [ "someone" ];
        };
        nebula = true;
      });
    "no aegis module skips" =
      !installed (hmNiten {
        nebula = true;
        withAegisModule = false;
      });
    "standalone skips" = !installed standaloneNiten;
    "config uses env vars" =
      let
        json = builtins.fromJSON full.xdg.configFile."opencode/opencode.json".text;
      in
      json.provider.openrouter.options.apiKey == "{env:OPENROUTER_API_KEY}"
      && json.mcp.hindsight.headers.Authorization == "Bearer {env:HINDSIGHT_API_KEY}"
      && json.mcp.hindsight.url == "https://hindsight.sea.fudo.dev/mcp/niten/";
  };

  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) cases);
in
if failed == [ ] then
  {
    pass = true;
    inherit cases;
  }
else
  throw "opencode gate tests failed: ${lib.concatStringsSep ", " failed}"
