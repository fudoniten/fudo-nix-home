# Checks the generic fudo.opencode and fudo.kube modules through the
# standalone mkModule.niten path: both off by default, and what they write
# when a host turns them on. Which hosts turn them on is nixos-config's
# business and is tested there.
#
#   nix eval --impure --json --expr \
#     'import ./tests/opencode.nix { flake = builtins.getFlake (toString ./.); }'
#
# Evaluates to { pass = true; ... } or throws naming the failed case.
{ flake }:

let
  inherit (flake.inputs) nixpkgs home-manager;
  inherit (nixpkgs) lib;

  hm =
    extra:
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
          stateVersion = "26.05";
        })
        extra
      ];
    }).config;

  plain = hm { };

  on = hm {
    fudo.opencode = {
      enable = true;
      secretEnvDir = "/run/aegis/users/niten/env";
      hindsight = {
        enable = true;
        url = "https://hindsight.example.com/";
      };
    };
    fudo.kube = {
      enable = true;
      clusters.prod = {
        server = "https://master-0.example.com:6443";
        tokenFile = "/run/aegis/users/niten/files/kube-prod-token";
        caFile = "/run/aegis/users/niten/files/kube-prod-ca.crt";
      };
    };
  };

  # The text refers to the Hindsight guide in the store; fromJSON refuses
  # string context, and only the structure matters here.
  oc = builtins.fromJSON (
    builtins.unsafeDiscardStringContext on.xdg.configFile."opencode/opencode.json".text
  );
  kc = builtins.fromJSON on.home.file.".kube/config".text;

  cases = {
    "opencode off by default" = !(plain.xdg.configFile ? "opencode/opencode.json");
    "kube off by default" = !(plain.home.file ? ".kube/config");
    "unconfigured opencode is the plain package" =
      plain.fudo.opencode.finalPackage == plain.fudo.opencode.package;
    "opencode reads keys from env" =
      oc.provider.openrouter.options.apiKey == "{env:OPENROUTER_API_KEY}"
      && oc.mcp.hindsight.headers.Authorization == "Bearer {env:HINDSIGHT_API_KEY}";
    "hindsight url is per bank" = oc.mcp.hindsight.url == "https://hindsight.example.com/mcp/niten/";
    "hindsight guide is an instruction" = builtins.length oc.instructions == 1;
    "secretEnvDir wraps opencode" = on.fudo.opencode.finalPackage != on.fudo.opencode.package;
    "kubeconfig uses the token file" =
      (builtins.head kc.users).user.tokenFile == "/run/aegis/users/niten/files/kube-prod-token";
    "kubeconfig sets the CA and context" =
      (builtins.head kc.clusters).cluster.certificate-authority
      == "/run/aegis/users/niten/files/kube-prod-ca.crt"
      && kc.current-context == "prod";
  };

  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) cases);
in
if failed == [ ] then
  {
    pass = true;
    inherit cases;
  }
else
  throw "opencode/kube tests failed: ${lib.concatStringsSep ", " failed}"
