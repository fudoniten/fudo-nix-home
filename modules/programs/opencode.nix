# OpenCode, configured for an OpenRouter model and optionally Hindsight
# long-term memory.
#
# This module is deliberately mechanism only: it is off by default and makes
# no decisions about *where* it should be on. The host side (nixos-config)
# decides that -- whether the host has the API keys, whether it can reach
# Hindsight, which Hindsight to use -- and sets these options, for example
# through `home-manager.sharedModules`.
#
# Keys are never written to the store. The config refers to them with
# OpenCode's `{env:NAME}` substitution, so they have to be in the
# environment OpenCode starts in. Login shells have them already when they
# come from Aegis env secrets. Processes that are not children of a login
# shell (an Emacs daemon started by systemd, which runs agent-shell) don't, so
# `secretEnvDir` wraps the opencode binary to load any missing variable from
# a directory of one-file-per-variable secrets before it starts.
#
# `instructions` is a plain list of files, so other modules (such as an
# AGENTS.md / agent-context module) can add their own; Hindsight adds its
# memory guide here when enabled.
{ inputs, ... }:

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.fudo.opencode;

  hindsightGuide = pkgs.writeText "opencode-hindsight.md" ''
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

  opencodeConfig = recursiveUpdate (
    {
      "$schema" = "https://opencode.ai/config.json";
      model = "openrouter/${cfg.model}";
      small_model = "openrouter/${cfg.smallModel}";
      provider.openrouter.options.apiKey = "{env:${cfg.apiKeyEnv}}";
      inherit (cfg) instructions;
    }
    // optionalAttrs (cfg.mcp != { }) { inherit (cfg) mcp; }
  ) cfg.settings;

  # Exports every regular file in secretEnvDir as a variable of that name,
  # unless the variable is already set -- the same rule Aegis's login-shell
  # export follows. Names must be valid shell identifiers.
  wrapped = pkgs.writeShellScriptBin "opencode" ''
    dir=${escapeShellArg cfg.secretEnvDir}
    if [ -d "$dir" ] && [ -r "$dir" ] && [ -x "$dir" ]; then
      for f in "$dir"/*; do
        [ -f "$f" ] && [ -r "$f" ] || continue
        n=''${f##*/}
        case "$n" in
          ""|[0-9]*|*[!A-Za-z0-9_]*) continue ;;
        esac
        [ -n "''${!n+x}" ] && continue
        export "$n=$(cat "$f")"
      done
    fi
    exec ${getExe cfg.package} "$@"
  '';
in
{
  options.fudo.opencode = with types; {
    enable = mkEnableOption "OpenCode configured for OpenRouter";

    package = mkOption {
      type = package;
      # Unstable: OpenCode moves fast, and the stable branch lags well behind.
      default = inputs.nixpkgsUnstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.opencode;
      defaultText = literalExpression "nixpkgsUnstable.opencode";
      description = "The OpenCode package.";
    };

    finalPackage = mkOption {
      type = package;
      readOnly = true;
      default = if cfg.secretEnvDir != null then wrapped else cfg.package;
      defaultText = literalExpression "package, wrapped when secretEnvDir is set";
      description = ''
        The opencode that is installed: `package`, wrapped to load
        `secretEnvDir` when that is set. Use this anywhere else opencode is
        put on a PATH (Emacs' exec-path, for instance), so the two agree.
      '';
    };

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

    apiKeyEnv = mkOption {
      type = str;
      default = "OPENROUTER_API_KEY";
      description = "Environment variable holding the OpenRouter API key.";
    };

    secretEnvDir = mkOption {
      type = nullOr str;
      default = null;
      example = "/run/aegis/users/alice/env";
      description = ''
        Directory of one-file-per-variable secrets (file name = variable
        name). When set, opencode is wrapped to export any of them that are
        not already in its environment, so it gets its keys even when not
        started from a login shell.
      '';
    };

    hindsight = {
      enable = mkEnableOption "the Hindsight memory MCP server";

      url = mkOption {
        type = str;
        example = "https://hindsight.example.com";
        description = "Base URL of the Hindsight API server.";
      };

      bank = mkOption {
        type = str;
        default = config.home.username;
        defaultText = literalExpression "config.home.username";
        description = "Hindsight memory bank the MCP endpoint is bound to.";
      };

      apiKeyEnv = mkOption {
        type = str;
        default = "HINDSIGHT_API_KEY";
        description = "Environment variable holding the Hindsight API key.";
      };
    };

    instructions = mkOption {
      type = listOf str;
      default = [ ];
      description = ''
        Instruction files (paths or globs) OpenCode loads into every session.
        Other modules append to this.
      '';
    };

    mcp = mkOption {
      type = attrsOf (attrsOf anything);
      default = { };
      description = "OpenCode MCP server definitions, merged with Hindsight's.";
    };

    settings = mkOption {
      type = attrsOf anything;
      default = { };
      description = "Extra opencode.json settings, merged over the generated ones.";
    };
  };

  config = mkIf cfg.enable {
    fudo.opencode = {
      instructions = mkIf cfg.hindsight.enable [ "${hindsightGuide}" ];
      mcp.hindsight = mkIf cfg.hindsight.enable {
        type = "remote";
        enabled = true;
        url = "${removeSuffix "/" cfg.hindsight.url}/mcp/${cfg.hindsight.bank}/";
        headers.Authorization = "Bearer {env:${cfg.hindsight.apiKeyEnv}}";
      };
    };

    home.packages = [ cfg.finalPackage ];

    xdg.configFile."opencode/opencode.json".text = builtins.toJSON opencodeConfig;
  };
}
