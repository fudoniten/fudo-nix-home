# OpenCode with an OpenRouter model and Hindsight long-term memory.
#
# The API keys are never written to the store or to a file here: they are
# Aegis env secrets (`aegis-user add-env OPENROUTER_API_KEY ...`), which the
# Aegis NixOS module exports into every login session of a user it decrypts
# for (`aegis.secrets.exportUserEnv`). The config only references them with
# OpenCode's `{env:NAME}` substitution.
#
# Because of that, the config is only useful on a host that
#   1. runs Aegis live and decrypts this user's secrets, and
#   2. is on the Nebula overlay, the only way to reach *.sea.fudo.dev.
# Both are read from the NixOS host config (`osConfig`), which Home Manager
# passes only when it runs as a NixOS module. In the standalone `mkModule`
# path (e.g. the work machine via work-home) there is no `osConfig`, so the
# gate is closed and nothing is written: the opencode binary stays a plain,
# unconfigured install.
{ ... }:

{
  config,
  lib,
  pkgs,
  ...
}@args:

with lib;
let
  cfg = config.fudo.opencode;

  osConfig = args.osConfig or null;

  username = config.home.username;

  aegisCfg = if osConfig == null then { } else osConfig.aegis.secrets or { };

  # Live Aegis (dry-run writes everything under /run/aegis-dry-run), env
  # export on, and this user among the ones whose secrets the host decrypts.
  hasAegisEnv =
    (aegisCfg.enable or false)
    && !(aegisCfg.dryRun or false)
    && (aegisCfg.exportUserEnv or false)
    && elem username (aegisCfg.users or [ ]);

  # nixos-config's services/nebula only enables a network on a host that
  # aegis-secrets has actually enrolled, so an enabled network is a reliable
  # "this host is on the overlay" signal.
  onNebula =
    osConfig != null
    && any (net: net.enable or false) (attrValues (osConfig.services.nebula.networks or { }));

  gateOpen = hasAegisEnv && (onNebula || !cfg.requireNebula);

  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    model = "openrouter/${cfg.model}";
    small_model = "openrouter/${cfg.smallModel}";
    provider.openrouter.options.apiKey = "{env:OPENROUTER_API_KEY}";
    mcp.hindsight = {
      type = "remote";
      enabled = true;
      url = "${cfg.hindsight.url}/mcp/${cfg.hindsight.bank}/";
      headers.Authorization = "Bearer {env:HINDSIGHT_API_KEY}";
    };
    instructions = [ "~/.config/opencode/memory.md" ];
  };

  memoryInstructions = ''
    # Long-term memory (Hindsight)

    You have persistent memory through the `hindsight` MCP server, shared
    across sessions and projects.

    - At the start of a task, use `recall` with a short description of the
      task, the repository and the user's request, and use what comes back.
    - When you learn something worth keeping (a user preference, a decision
      and its reason, how a system or repository works, a fix for a recurring
      problem), store it with `retain` as a short, self-contained statement.
      Include the project or repository name so it can be found later.
    - Use `reflect` when a question needs reasoning over many memories, such
      as "what do I know about how this user deploys hosts?".
    - Never store secrets, API keys, passwords or tokens.
  '';
in
{
  options.fudo.opencode = with types; {
    enable = mkEnableOption ''
      OpenCode configured for OpenRouter and Hindsight memory. Takes effect
      only on NixOS hosts where Aegis exports this user's env secrets (and,
      with requireNebula, that are on the Nebula overlay)
    '';

    model = mkOption {
      type = str;
      default = "z-ai/glm-5.3";
      description = "OpenRouter model id for the main agent.";
    };

    smallModel = mkOption {
      type = str;
      default = cfg.model;
      defaultText = literalExpression "config.fudo.opencode.model";
      description = "OpenRouter model id for titles and other light tasks.";
    };

    requireNebula = mkOption {
      type = bool;
      default = true;
      description = ''
        Only write the config on hosts that are on the Nebula overlay, since
        Hindsight is reachable only from there.
      '';
    };

    hindsight = {
      url = mkOption {
        type = str;
        default = "https://hindsight.sea.fudo.dev";
        description = "Base URL of the Hindsight API server.";
      };

      bank = mkOption {
        type = str;
        default = username;
        defaultText = literalExpression "config.home.username";
        description = "Hindsight memory bank the MCP endpoint is bound to.";
      };
    };

    active = mkOption {
      type = bool;
      readOnly = true;
      default = cfg.enable && gateOpen;
      defaultText = literalExpression "enable && <Aegis env secrets> && <on Nebula>";
      description = "Whether the gate passed and the config is installed.";
    };
  };

  config = mkIf cfg.active {
    xdg.configFile = {
      "opencode/opencode.json".text = builtins.toJSON opencodeConfig;
      "opencode/memory.md".text = memoryInstructions;
    };
  };
}
