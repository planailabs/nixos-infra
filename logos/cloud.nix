{ config, lib, pkgs, ... }:

# The plan.ai cloud console: what customers pick products in, and what drives
# the fleet of Incus instances behind them. Its secrets — the encryption key,
# the tokens for Zitadel, web-agency and the inference gateway, and the
# sign-in providers — are in private/logos-cloud.nix.
{
  services.plan-ai-cloud = {
    enable = true;

    settings = {
      web.port = 7390;

      payments = {
        provider = "fake";
        trial_days = 14;
      };

      fleet = {
        alias_prefix = "plan-ai";
        instance_prefix = "planai";
        boot_timeout_secs = 180;
        sync_interval_secs = 30;
      };

      # Images come from the registry on cloud-images, which the regions pull
      # from themselves — so this console carries none of them in its own
      # store, and [fleet.images] stays empty.
      registry = {
        url = "https://cloud-images.plan.ai";
        channel = "stable";
      };

      zitadel = {
        url = "https://id.plan.ai";
        project_name = "plan.ai services";
        callback_path = "/auth/callback";
      };

      web_agency = {
        url = "https://agency.plan.ai";
        # Every organization's services answer under <slug>.cloud.plan.ai,
        # served by web-agency's plan.ai zone.
        shared_domain = "cloud.plan.ai";
      };

      inference = {
        base_url = "https://codex.plan.ai";
        markup_percent = 0;
        default_model = "gpt-5.6-sol";
      };

      features = {
        self_hosting = false;
        mac_mgmt = false;
        hippocampus = false;
      };
    };
  };

  services.nginx.virtualHosts."cloud.plan.ai" = {
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
