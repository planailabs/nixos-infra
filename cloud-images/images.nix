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
    environmentFile = "/etc/plan-ai-images.env";
  };
}
