# Agent context: an AGENTS.md, reference documents and skills that describe
# the machine and network an AI coding agent is running in, installed where
# OpenCode, Claude Code and Codex look for them.
#
# This module is deliberately generic and does nothing unless something turns
# it on. It knows nothing about any network: the content comes from whoever
# sets the options -- in the Fudo fleet that is nixos-config, which describes
# each host's domain, site, Kubernetes cluster and services. Several modules
# can contribute independently, because every piece is a named attribute:
#
#   fudo.agent-context = {
#     enable = true;
#     sections.network = {            # composed into AGENTS.md, by `order`
#       order = 200;
#       text = "## Network\n...";
#     };
#     documents.kubernetes = {        # ~/.config/agents/docs/kubernetes.md,
#       description = "...";          # listed (not inlined) in AGENTS.md
#       text = "...";
#     };
#     skills.restart-pod = {          # ~/.agents/skills/restart-pod/SKILL.md
#       description = "...";
#       text = "...";
#     };
#   };
#
# AGENTS.md is the always-loaded part, so it should stay short: put detail
# in documents (read on demand) and procedures in skills (loaded when the
# task matches the description).
#
# The canonical copy lives under ~/.config/agents and ~/.agents/skills; each
# enabled target links the same files into that harness's own location.
_:

{
  config,
  lib,
  ...
}:

with lib;
let
  cfg = config.fudo.agent-context;

  homeDir = config.home.homeDirectory;

  # Text from an optional source file followed by inline text, so a section
  # can be a checked-in Markdown file, a generated string, or both.
  contentOf =
    item:
    concatStringsSep "\n" (
      filter (s: s != "") [
        (optionalString (item.source != null) (builtins.readFile item.source))
        item.text
      ]
    );

  # Installed files end in a newline, however their pieces were written.
  asFile = s: if s == "" || hasSuffix "\n" s then s else s + "\n";

  contentOptions = {
    text = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Markdown content. Several definitions of the same item are joined,
        so independent modules can add to one section.
      '';
    };

    source = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Markdown file whose content precedes `text`.";
    };
  };

  sectionModule = {
    options = contentOptions // {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to include this section.";
      };

      order = mkOption {
        type = types.int;
        default = 1000;
        description = ''
          Position in AGENTS.md, lowest first; ties sort by name. The
          generated header is at 0 and the document index at 9000.
        '';
      };
    };
  };

  documentModule =
    { name, ... }:
    {
      options = contentOptions // {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to install this document.";
        };

        description = mkOption {
          type = types.str;
          description = ''
            One line on what the document covers, shown in the AGENTS.md
            index so the agent knows when to read it.
          '';
        };

        fileName = mkOption {
          type = types.str;
          default = "${name}.md";
          defaultText = literalExpression ''"''${name}.md"'';
          description = "File name under the documents directory.";
        };
      };
    };

  skillModule =
    { name, ... }:
    {
      options = contentOptions // {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to install this skill.";
        };

        description = mkOption {
          type = types.str;
          description = ''
            When to use the skill. Harnesses show only this line to the
            model, and load the body when a task matches it.
          '';
        };

        directory = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            A complete skill directory (its own SKILL.md plus any scripts or
            references) to install as-is. When set, `text`, `source` and
            `description` are not used to build a SKILL.md.
          '';
        };
      };
    };

  enabledSections = filterAttrs (_: s: s.enable) cfg.sections;
  enabledDocuments = filterAttrs (_: d: d.enable) cfg.documents;
  enabledSkills = filterAttrs (_: s: s.enable) cfg.skills;

  docPath = doc: "${cfg.documentsDir}/${doc.fileName}";

  # The index is generated, so a document added anywhere is always listed
  # with its real path, and AGENTS.md never inlines it.
  indexSection = optionalAttrs (enabledDocuments != { }) {
    reference-documents = {
      order = 9000;
      text = ''
        ## Reference documents

        Read these when a task needs the detail; they are not loaded by
        default.

        ${concatStringsSep "\n" (
          mapAttrsToList (_: doc: "- `${docPath doc}`: ${doc.description}") enabledDocuments
        )}
      '';
    };
  };

  headerSection = optionalAttrs (cfg.title != null) {
    header = {
      order = 0;
      text = "# ${cfg.title}\n";
    };
  };

  allSections = mapAttrsToList (name: s: s // { inherit name; }) (
    headerSection // indexSection // mapAttrs (_: s: s // { text = contentOf s; }) enabledSections
  );

  trimNewlines =
    s:
    let
      t = removeSuffix "\n" s;
    in
    if t == s then s else trimNewlines t;

  agentsMd =
    concatStringsSep "\n\n" (
      map (s: trimNewlines s.text) (
        sort (a: b: if a.order == b.order then a.name < b.name else a.order < b.order) (
          filter (s: s.text != "") allSections
        )
      )
    )
    + "\n";

  skillMd =
    name: skill:
    ''
      ---
      name: ${name}
      description: ${builtins.toJSON skill.description}
      ---

    ''
    + asFile (contentOf skill);

  # home.file entries for one skills root (e.g. ~/.agents/skills).
  skillFiles =
    root:
    concatMapAttrs (
      name: skill:
      if skill.directory != null then
        {
          "${root}/${name}".source = skill.directory;
        }
      else
        {
          "${root}/${name}/SKILL.md".text = skillMd name skill;
        }
    ) enabledSkills;

  agentsFileRel = "${cfg.relativeDir}/AGENTS.md";

  target = name: cfg.targets.${name}.enable;

in
{
  options.fudo.agent-context = with types; {
    enable = mkEnableOption ''
      an AGENTS.md, documents and skills describing this machine's
      environment for AI coding agents
    '';

    title = mkOption {
      type = nullOr str;
      default = "Environment";
      description = "Top-level heading of the generated AGENTS.md, or null for none.";
    };

    sections = mkOption {
      type = attrsOf (submodule sectionModule);
      default = { };
      description = "Named Markdown sections composed, by `order`, into AGENTS.md.";
    };

    documents = mkOption {
      type = attrsOf (submodule documentModule);
      default = { };
      description = ''
        Reference documents installed beside AGENTS.md and listed in it, for
        detail an agent should read only when a task needs it.
      '';
    };

    skills = mkOption {
      type = attrsOf (submodule skillModule);
      default = { };
      description = ''
        Agent skills, keyed by skill name (lowercase, hyphenated), installed
        as `<name>/SKILL.md` in each enabled target's skills directory.
      '';
    };

    relativeDir = mkOption {
      type = str;
      default = ".config/agents";
      description = "Where the canonical AGENTS.md and documents go, relative to home.";
    };

    documentsDir = mkOption {
      type = str;
      readOnly = true;
      default = "${homeDir}/${cfg.relativeDir}/docs";
      defaultText = literalExpression ''"''${config.home.homeDirectory}/''${relativeDir}/docs"'';
      description = "Absolute path of the installed documents.";
    };

    agentsFile = mkOption {
      type = str;
      readOnly = true;
      default = "${homeDir}/${agentsFileRel}";
      defaultText = literalExpression ''"''${config.home.homeDirectory}/''${relativeDir}/AGENTS.md"'';
      description = "Absolute path of the generated AGENTS.md.";
    };

    targets = {
      agents.enable = mkOption {
        type = bool;
        default = true;
        description = ''
          Install skills in ~/.agents/skills, the harness-neutral location
          OpenCode and Codex both read.
        '';
      };

      opencode.enable = mkOption {
        type = bool;
        default = true;
        description = ''
          Link AGENTS.md to ~/.config/opencode/AGENTS.md, which OpenCode
          loads as its global rules. (It also reads ~/.agents/skills.)
        '';
      };

      claude.enable = mkOption {
        type = bool;
        default = false;
        description = ''
          Link AGENTS.md to ~/.claude/CLAUDE.md and skills into
          ~/.claude/skills for Claude Code. Off by default because
          ~/.claude/CLAUDE.md is often hand-written, and Home Manager refuses
          to activate over an unmanaged file.
        '';
      };

      codex.enable = mkOption {
        type = bool;
        default = false;
        description = "Link AGENTS.md to ~/.codex/AGENTS.md for Codex.";
      };
    };
  };

  config = mkIf cfg.enable {
    home.file = mkMerge [
      {
        ${agentsFileRel}.text = agentsMd;
      }
      (mapAttrs' (
        _: doc:
        nameValuePair "${cfg.relativeDir}/docs/${doc.fileName}" {
          text = asFile (contentOf doc);
        }
      ) enabledDocuments)
      (mkIf (target "agents") (skillFiles ".agents/skills"))
      (mkIf (target "opencode") {
        ".config/opencode/AGENTS.md".text = agentsMd;
      })
      (mkIf (target "claude") (
        {
          ".claude/CLAUDE.md".text = agentsMd;
        }
        // skillFiles ".claude/skills"
      ))
      (mkIf (target "codex") {
        ".codex/AGENTS.md".text = agentsMd;
      })
    ];

    assertions = mapAttrsToList (name: _: {
      assertion = builtins.match "[a-z0-9]+(-[a-z0-9]+)*" name != null;
      message = "fudo.agent-context.skills.${name}: skill names must be lowercase and hyphenated.";
    }) cfg.skills;
  };
}
