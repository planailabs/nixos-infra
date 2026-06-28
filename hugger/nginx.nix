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
    "hugger-omen.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://127.0.0.1:7860/";
        proxyWebsockets = true;
      };
      # Model snapshots can be large; allow big uploads and long-running
      # archive jobs to stream without nginx timing out or buffering them.
      extraConfig = ''
        client_max_body_size 50g;
        client_body_timeout 3600;
        proxy_request_buffering off;
        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
        proxy_connect_timeout 3600;
      '';
    };
  };
}
