{ config, pkgs, lib, ... }:

with lib;

let
  h = a: a // {
    enableACME = true;
    forceSSL = true;
  };

  # The xzar write plane: an upload token may publish a store path that the
  # server signs with the key the whole fleet substitutes from, and uploads are
  # not token-scoped, signature-verified or overwrite-protected
  # (mkg20001/xzar@dca77eb, the pinned rev). Keep the signing path off the
  # internet; only the nix-image CI runners reach it — incus containers on
  # hyperion, cf. mmrcd's incus_url. Evidence: since 2026-08-15 every
  # uploadNar/lock/check/finalizePin in /var/log/nginx/access.log* came from
  # 2a01:4f8:c012:2caf::/64 (before that, runners on 2a01:4f8:262:494f until
  # 2026-07-11 and ygg.mkg20001.io over IPv4 until 2026-08-14). Those two now
  # get 403; move the runners and this prefix needs the same edit, or
  # mac-mgmt's prebuild upload loop retries the 403 into its 6h timeout.
  ciWriteOnly = {
    proxyPass = "http://localhost:17788";
    extraConfig = ''
      allow 2a01:4f8:c012:2caf::/64;
      deny all;
    '';
  };
in
{
  imports = [ ../modules/nginx-security-headers.nix ];

  services.nginx.enable = true;

  services.nginx.enableReload = true;
  services.nginx.recommendedBrotliSettings = true;
  services.nginx.recommendedGzipSettings = true;
  services.nginx.recommendedOptimisation = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.recommendedTlsSettings = true;

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx.virtualHosts = {
    "xzar.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://localhost:17788/";
      };
      locations."= /uploadNar" = ciWriteOnly;
      locations."= /lock/request" = ciWriteOnly;
      locations."= /lock/extend" = ciWriteOnly;
      locations."= /lock/clear" = ciWriteOnly;
      locations."= /finalizePin" = ciWriteOnly;
      locations."= /check" = ciWriteOnly;
      extraConfig = ''
        client_max_body_size 10g;
        client_body_timeout 3600;
        proxy_request_buffering off;
        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
        proxy_connect_timeout 3600;
      '';
    };

    "acme.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://localhost:3444/";
      };
    };

    "chat.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://localhost:4321/";
        proxyWebsockets = true;
      };
    };

    "kan.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://127.0.0.1:3055/";
        proxyWebsockets = true;
      };
    };

    "grafana.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://127.0.0.1:3434/";
        proxyWebsockets = true;
      };
      # Anonymous /api/health publishes the exact Grafana build (13.2.3) for
      # free CVE matching.
      locations."= /api/health".return = "404";
    };

    "prometheus.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://localhost:9090/";
      };
      # Allow either oauth2 (browser) or basic auth (grafana datasource).
      extraConfig = ''
        satisfy any;
      '';
      locations."= /oauth2/auth".extraConfig = ''
        auth_basic off;
      '';
      locations."@redirectToAuth2ProxyLogin".extraConfig = ''
        auth_basic off;
      '';
    };

    "login.plan.ai" = h {
      # oauth2-proxy's front door: every protected host redirects here with
      # rd= pointing back at itself. Without a location the vhost served the
      # stock "Welcome to nginx!" page; send bare visits on to plan.ai.
      locations."/".return = "302 https://plan.ai/";
    };

    "api.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://localhost:7378/";
      };
      extraConfig = ''
        proxy_read_timeout 60;
        proxy_send_timeout 60;
        proxy_connect_timeout 60;
      '';
    };

    "vpn.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8091/";
        proxyWebsockets = true;
      };
    };

    "mgmt.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://localhost:7377/";
        proxyWebsockets = true;
      };
      locations."/daemon/" = {
        proxyPass = "http://localhost:7378/";
      };
      extraConfig = ''
        proxy_read_timeout 60;
        proxy_send_timeout 60;
        proxy_connect_timeout 60;
      '';
    };

    "runner.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://localhost:9400/";
        proxyWebsockets = true;
      };
    };

    "memvault.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8401";
        proxyWebsockets = true;
      };
      locations."/api" = {
        proxyPass = "http://127.0.0.1:8401";
        extraConfig = ''
          auth_request off;
        '';
      };
    };

    "ghgl.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8877/";
        proxyWebsockets = true;
      };
    };

    "auth.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://127.0.0.1:3636/";
        proxyWebsockets = true;
      };
      extraConfig = ''
        proxy_buffer_size       16k;
        proxy_buffers           8 16k;
        proxy_busy_buffers_size 32k;
      '';
    };
  };
}
