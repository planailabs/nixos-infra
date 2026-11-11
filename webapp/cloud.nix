{ inputs, ... }:

# cms.webapp.agency: the plan.ai cloud console (logos/cloud.nix) for
# webapp.agency. It sells cms-agent only; its customers' instances run on
# hyperion in their own incus project (the region registered in the console),
# their sites under <customer>.cms.webapp.agency through webapp-harbor. Images
# and inference are plan.ai's. Secrets: private/webapp-cloud.nix.
{
  imports = [ "${inputs.self.private}/webapp-cloud.nix" ];

  services.plan-ai-cloud = {
    enable = true;
    settings = {
      web.port = 7390;

      payments = {
        provider = "fake";
        trial_days = 14;
      };

      fleet = {
        # The region is shared with cloud.plan.ai: use its images (plan-ai-<product>).
        alias_prefix = "plan-ai";
        instance_prefix = "webapp";
        boot_timeout_secs = 180;
        sync_interval_secs = 30;
      };

      registry = {
        url = "https://cloud-images.plan.ai";
        channel = "stable";
        # The registry is shared with cloud.plan.ai, whose regions' credentials
        # are named by plain slug (de-fsn-1): ours get a prefix.
        credential_prefix = "webapp-";
      };

      zitadel = {
        url = "https://id.webapp.agency";
        project_name = "webapp.agency services";
        callback_path = "/auth/callback";
      };

      harbor = {
        url = "https://harbor.webapp.agency";
        # Every organization's services answer under <slug>.cms.webapp.agency,
        # served by webapp-harbor's webapp.agency zone.
        shared_domain = "cms.webapp.agency";
      };

      inference = {
        base_url = "https://codex.plan.ai";
        markup_percent = 0;
        default_model = "gpt-5.6-sol";
      };

      features.products = [ "cms-agent" ];
    };
  };

  services.nginx.virtualHosts."cms.webapp.agency" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:7390/";
      # The console's chat sidebar is an event stream.
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 3600s;
        proxy_buffering off;
      '';
    };
  };
}
