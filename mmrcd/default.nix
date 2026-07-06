{ inputs, lib, pkgs, ... }: with lib; {
  # services.mmrcd comes from mac-mgmt.nixosModules.mmrcd, imported in the
  # flake's nixosConfigurations entry (like the relay/runner hosts).
  imports = [
    ../modules/common.nix
    ../modules/container.nix
  ];

  system.stateVersion = "26.11";
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "mmrcd";

  # Local incus, used by mmrcd to spin up antithesis clusters (one ephemeral
  # project per run). In an incus container this needs the parent to allow
  # nesting (security.nesting=true on this instance).
  virtualisation.incus.enable = true;
  virtualisation.incus.softDaemonRestart = true;

  # mmrcd orchestration daemon (loopback API). The bearer token is read from a
  # file at runtime; provision /var/lib/mmrcd/token out of band (or point
  # tokenFile at a secret from the private submodule).
  services.mmrcd = {
    enable = true;
    tokenFile = "/var/lib/mmrcd/token";
    settings = {
      listen = "127.0.0.1:7390";
      incus_backend = "unix";
      incus_project_prefix = "mmrc";
      registry = "registry.plan.ai/plan-ai/mac-mgmt";
      gitlab_url = "https://git.plan.ai";
      gitlab_project = "plan-ai/mac-mgmt";
      default_ref = "trunk";
    };
    # gitlabTokenFile = "/var/lib/mmrcd/gitlab-token";  # registry/CI is private
  };

  # mmr-causality provides both `mmrcd` and the `mmrc` CLI on PATH.
  environment.systemPackages = [ pkgs.mmr-causality pkgs.incus ];
}
