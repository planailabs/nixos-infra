{ inputs, lib, ... }: with lib; {
  # webapp.agency: its own Zitadel (id.webapp.agency), cloud console
  # (cms.webapp.agency) and chat (agent.webapp.agency), on logos' pattern.
  # Its Harbor is webapp-harbor. An incus container on atlas, IPv6 only:
  # eth0's address is set on the incus device (README), there is no public0.
  # No ../modules/postgres-upgrade.nix: it migrates an existing 17 cluster, and
  # its ReadWritePaths on the missing 17 directory keeps Postgres from starting.
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/webapp.nix"
    ./zitadel.nix
    ./cloud.nix
    ./chat.nix
  ];

  system.stateVersion = "26.11";
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "webapp";

  services.nginx = {
    enable = true;
    enableReload = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Certificates from logos' acme-distributor (its "webapp" entry,
  # *.webapp.agency over Cloudflare DNS); the token is in private/webapp.nix.
  security.acme.distributor-server = "https://acme.plan.ai";

  services.zitadel.enable = true;
}
