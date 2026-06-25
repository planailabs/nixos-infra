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
    "codex.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080/";
        proxyWebsockets = true;
      };
      # LLM responses stream and can run long; relax the proxy timeouts and
      # disable response buffering so tokens flush to the client as they arrive.
      extraConfig = ''
        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
        proxy_connect_timeout 60;
        proxy_buffering off;
        client_max_body_size 50m;
      '';
    };
  };
}
