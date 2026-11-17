# Checks modules/programs/agent-context.nix: it writes nothing unless
# enabled, composes sections in order with a generated document index, and
# installs documents and skills where each enabled harness looks.
#
#   nix eval --impure --json --expr \
#     'import ./tests/agent-context.nix { flake = builtins.getFlake (toString ./.); }'
#
# Evaluates to { pass = true; ... } or throws naming the failed case.
{ flake }:

let
  inherit (flake.inputs) nixpkgs home-manager;
  inherit (nixpkgs) lib;

  stateVersion = "26.05";

  pkgs = import nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };

  # The module alone, so the test exercises its own defaults and nothing a
  # user file sets.
  hmWith =
    modules:
    (home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        (import ../modules/programs/agent-context.nix { })
        {
          home = {
            username = "tester";
            homeDirectory = "/home/tester";
            inherit stateVersion;
          };
        }
      ]
      ++ modules;
    }).config;

  standaloneNiten =
    (home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        (flake.mkModule.niten {
          username = "niten";
          email = "niten@example.com";
          home-directory = "/home/niten";
          inherit stateVersion;
        })
      ];
    }).config;

  files = hm: hm.home.file;
  has = hm: path: (files hm) ? ${path};
  textOf = hm: path: (files hm).${path}.text;

  # Two modules contributing to the same context, as nixos-config's layers do.
  composed = hmWith [
    {
      fudo.agent-context = {
        enable = true;
        sections = {
          network = {
            order = 200;
            text = "## Network\n\nLAN is 10.0.0.0/24.";
          };
          hosts.text = "## Hosts\n\n- gateway";
          disabled = {
            enable = false;
            text = "## Should not appear";
          };
        };
        documents.kubernetes = {
          description = "The cluster and how to reach it.";
          text = "# Kubernetes\n\nUse kubectl.";
        };
        skills.check-pods = {
          description = "Use when asked whether the cluster is healthy: lists failing pods.";
          text = "Run `kubectl get pods -A | grep -v Running`.";
        };
      };
    }
    {
      fudo.agent-context.sections.network.text = "Gateway is fimbria.";
    }
  ];

  agentsMd = textOf composed ".config/agents/AGENTS.md";

  # Index of the first occurrence of `needle` in `haystack`, or -1.
  indexOf =
    needle: haystack:
    let
      parts = lib.splitString needle haystack;
    in
    if lib.length parts < 2 then -1 else lib.stringLength (lib.head parts);

  before = a: b: indexOf a agentsMd >= 0 && indexOf a agentsMd < indexOf b agentsMd;

  allTargets = hmWith [
    {
      fudo.agent-context = {
        enable = true;
        targets = {
          claude.enable = true;
          codex.enable = true;
        };
        skills.check-pods = {
          description = "x";
          text = "y";
        };
      };
    }
  ];

  cases = {
    "off by default" = !(has (hmWith [ ]) ".config/agents/AGENTS.md");
    "standalone niten writes nothing" =
      !(has standaloneNiten ".config/agents/AGENTS.md")
      && !(has standaloneNiten ".config/opencode/AGENTS.md");
    "header first" = lib.hasPrefix "# Environment\n" agentsMd;
    "sections ordered by order then name" = before "## Network" "## Hosts";
    "definitions of one section merge" =
      lib.hasInfix "LAN is 10.0.0.0/24." agentsMd && lib.hasInfix "Gateway is fimbria." agentsMd;
    "disabled section left out" = !(lib.hasInfix "Should not appear" agentsMd);
    "document index last, with absolute path" =
      before "## Hosts" "## Reference documents"
      && lib.hasInfix "`/home/tester/.config/agents/docs/kubernetes.md`: The cluster and how to reach it." agentsMd;
    "document installed" =
      textOf composed ".config/agents/docs/kubernetes.md" == "# Kubernetes\n\nUse kubectl.\n";
    "opencode target on by default" = textOf composed ".config/opencode/AGENTS.md" == agentsMd;
    "claude and codex off by default" =
      !(has composed ".claude/CLAUDE.md") && !(has composed ".codex/AGENTS.md");
    "skill has frontmatter" = lib.hasPrefix "---\nname: check-pods\ndescription: \"Use when asked" (
      textOf composed ".agents/skills/check-pods/SKILL.md"
    );
    "claude and codex targets" =
      has allTargets ".claude/CLAUDE.md"
      && has allTargets ".claude/skills/check-pods/SKILL.md"
      && has allTargets ".codex/AGENTS.md";
    "agentsFile path" =
      composed.fudo.agent-context.agentsFile == "/home/tester/.config/agents/AGENTS.md";
  };

  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) cases);
in
if failed == [ ] then
  {
    pass = true;
    inherit cases;
  }
else
  throw "agent-context tests failed: ${lib.concatStringsSep ", " failed}"
