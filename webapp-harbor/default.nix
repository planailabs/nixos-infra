{ inputs, lib, ... }: with lib; {
  # webapp.agency's Harbor (harbor.webapp.agency): the domains, certificates
  # and edge behind cms.webapp.agency's customers (<customer>.cms.webapp.agency).
  # The harbor host's config (./harbor) with its own database and tokens. An
  # incus container on atlas, IPv6 only: eth0's address is set on the incus
  # device, there is no public0. harbor-proxy issues its own certificates.
  # No ../modules/postgres-upgrade.nix: it migrates an existing 17 cluster, and
  # its ReadWritePaths on the missing 17 directory keeps Postgres from starting.
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/webapp-harbor.nix"
  ];

  system.stateVersion = "26.11";
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "webapp-harbor";

  services.harbor-server = {
    enable = true;
    settings = {
      web.port = 7380;
      proxy = {
        domain = "harbor.webapp.agency";
        acme_email = "admin@plan.ai";
      };
      local_hosting.dir = "/var/lib/harbor-server/web";
    };
  };

  services.harbor-proxy = {
    enable = true;
    openFirewall = true;
  };
}
