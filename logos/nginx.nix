{ config, pkgs, lib, ... }:

with lib;

let
  h = a: a // {
    enableACME = true;
    forceSSL = true;
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
