# kubectl access to one or more Kubernetes clusters, authenticated with a
# bearer token read from a file at run time.
#
# Mechanism only, like fudo.opencode: off by default, and the host side
# (nixos-config) decides which clusters a host gets and where their tokens
# are. The kubeconfig refers to the token and CA by path (`tokenFile`,
# `certificate-authority`), so neither enters the store; until the files
# exist, kubectl just fails to authenticate.
#
# Writes ~/.kube/config (JSON, which kubectl reads like YAML) and installs
# kubectl. Anything that runs kubectl -- a shell, OpenCode's bash tool,
# kubernetes-el in Emacs -- uses it with no further setup.
_:

{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.fudo.kube;

  clusterOpts =
    { name, ... }:
    {
      options = with types; {
        server = mkOption {
          type = str;
          example = "https://master-0.example.com:6443";
          description = "API server URL.";
        };

        tokenFile = mkOption {
          type = str;
          description = "Path to a file holding the bearer token.";
        };

        caFile = mkOption {
          type = nullOr str;
          default = null;
          description = ''
            Path to the API server's CA certificate. Null trusts the system
            CA store.
          '';
        };

        namespace = mkOption {
          type = nullOr str;
          default = null;
          description = "Default namespace for this context.";
        };
      };
    };

  mkCluster = name: c: {
    inherit name;
    cluster = {
      inherit (c) server;
    }
    // optionalAttrs (c.caFile != null) { certificate-authority = c.caFile; };
  };

  mkUser = name: c: {
    inherit name;
    user.tokenFile = c.tokenFile;
  };

  mkContext = name: c: {
    inherit name;
    context = {
      cluster = name;
      user = name;
    }
    // optionalAttrs (c.namespace != null) { inherit (c) namespace; };
  };

  kubeconfig = {
    apiVersion = "v1";
    kind = "Config";
    preferences = { };
    clusters = mapAttrsToList mkCluster cfg.clusters;
    users = mapAttrsToList mkUser cfg.clusters;
    contexts = mapAttrsToList mkContext cfg.clusters;
    current-context = cfg.currentContext;
  };
in
{
  options.fudo.kube = with types; {
    enable = mkEnableOption "kubectl with a managed kubeconfig";

    package = mkOption {
      type = package;
      default = pkgs.kubectl;
      defaultText = literalExpression "pkgs.kubectl";
      description = "The kubectl package.";
    };

    clusters = mkOption {
      type = attrsOf (submodule clusterOpts);
      default = { };
      description = ''
        Clusters, by name. Each becomes a cluster, user and context of that
        name in the kubeconfig.
      '';
    };

    currentContext = mkOption {
      type = nullOr str;
      default =
        let
          names = attrNames cfg.clusters;
        in
        if length names == 1 then head names else null;
      defaultText = literalExpression "the only cluster, if there is exactly one";
      description = "Context kubectl uses by default.";
    };

    configFile = mkOption {
      type = str;
      readOnly = true;
      default = "${config.home.homeDirectory}/.kube/config";
      description = "Path of the generated kubeconfig.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.currentContext == null || hasAttr cfg.currentContext cfg.clusters;
        message = "fudo.kube.currentContext names a cluster not in fudo.kube.clusters.";
      }
    ];

    home.packages = [ cfg.package ];

    home.file.".kube/config" = mkIf (cfg.clusters != { }) {
      text = builtins.toJSON (filterAttrs (_: v: v != null) kubeconfig);
    };
  };
}
