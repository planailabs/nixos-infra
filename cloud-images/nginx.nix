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
    "cloud-images.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://127.0.0.1:7391/";
        extraConfig = ''
          # Images are a few hundred megabytes each way: CI uploads them and
          # every region downloads them. Neither is a request to buffer or to
          # give up on.
          client_max_body_size 8g;
          proxy_request_buffering off;
          proxy_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        '';
      };
    };
  };
}
