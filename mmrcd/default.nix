{ inputs, lib, pkgs, ... }: with lib; {
  # services.mmrcd comes from mac-mgmt.nixosModules.mmrcd, imported in the
  # flake's nixosConfigurations entry (like the relay/runner hosts).
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    ./nginx.nix
    # Sets security.acme.distributor-token (shared distributor secret).
    "${inputs.self.private}/mmrcd.nix"
  ];

  system.stateVersion = "26.11";
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "mmrcd";

  # Front the loopback API with nginx (TLS via the acme distributor shim).
  security.acme.distributor-server = "https://acme.plan.ai";

  # mmrcd orchestration daemon (loopback API). It drives a REMOTE incus over
  # HTTPS/mTLS (no local incus daemon here). Provision the secrets out of band:
  #   /var/lib/mmrcd/token             — the API bearer token
  #   /var/lib/mmrcd/incus-client.crt  — client cert trusted by the remote incus
  #   /var/lib/mmrcd/incus-client.key  — client key
  # (register the client cert on the remote with `incus config trust add`).
  services.mmrcd = {
    enable = true;
    tokenFile = "/var/lib/mmrcd/token";
    settings = {
      listen = "127.0.0.1:7390";
      incus_backend = "https";
      incus_url = "https://[2a01:4f8:c012:2caf:2000::2]:8443";
      incus_client_cert = "/var/lib/mmrcd/incus-client.crt";
      incus_client_key = "/var/lib/mmrcd/incus-client.key";
      incus_project_prefix = "mmrc";
      registry = "registry.plan.ai/plan-ai/mac-mgmt";
      gitlab_url = "https://git.plan.ai";
      gitlab_project = "plan-ai/mac-mgmt";
      default_ref = "trunk";
    };
    # gitlabTokenFile = "/var/lib/mmrcd/gitlab-token";  # registry/CI is private
  };

  # mmr-causality provides both `mmrcd` and the `mmrc` CLI on PATH.
  environment.systemPackages = [ pkgs.mmr-causality ];
}
