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
    # scanner.plan.ai is covered by the distributor's *.plan.ai wildcard cert.
    "scanner.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080/";
      };
      # Scans can run long; give the API room before nginx times out.
      extraConfig = ''
        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
        proxy_connect_timeout 60;
      '';
    };
  };
}
