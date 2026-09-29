{ inputs, config, pkgs, lib, ... }:

{
  imports = [ inputs.plan-ai-cloud.nixosModules.images ];

  nixpkgs.overlays = [ inputs.plan-ai-cloud.overlays.default ];

  # The fleet's image registry: a simplestreams tree the regions pull from,
  # each with a credential of its own that only works from its own addresses.
  # nginx in front holds the certificate, so the service listens on loopback
  # and reads the client address out of X-Forwarded-For — believed from the
  # proxy and from nowhere else.
  services.plan-ai-images = {
    enable = true;
    # PLAN_AI_IMAGES_ADMIN_TOKEN — the console mints and revokes credentials
    # PLAN_AI_IMAGES_PUBLISH_TOKEN — CI adds images
    environmentFile = "/var/keys/plan-ai-images.env";
  };

  # The tree is the one thing here worth keeping: rebuilding an image is
  # cheap, but a region pulling one that has gone is not.
  systemd.tmpfiles.rules = [ "d /var/lib/plan-ai-images 0700 root root -" ];
}
