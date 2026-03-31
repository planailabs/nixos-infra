{ config, pkgs, lib, ... }:

with lib;

let
  h = a: a // {
    enableACME = true;
    forceSSL = true;
  };
in
{
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

    "update.plan.ai" = h {
      root = "/srv/update";
    };

    "chat.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://localhost:4321/";
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
    };
  };
}
