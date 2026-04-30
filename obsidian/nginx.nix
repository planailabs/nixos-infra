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
    "obsidian.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://127.0.0.1:3010";
        proxyWebsockets = true;
      };
      extraConfig = ''
        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
        proxy_connect_timeout 60;
        # MCP Streamable HTTP can carry SSE — disable buffering on the response.
        proxy_buffering off;
      '';
    };
  };
}
