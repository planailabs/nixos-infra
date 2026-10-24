{ config, pkgs, lib, ... }:

with lib;

let
  h = a: a // {
    enableACME = true;
    forceSSL = true;
  };

  # The write plane signs whatever a write token uploads; keep it off the
  # internet, CI runners only (rationale and evidence: logos/nginx.nix).
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
    "xzar.peira.plan.ai" = h {
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
        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
        proxy_connect_timeout 3600;
      '';
    };

    "api.peira.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://localhost:7378/";
      };
      extraConfig = ''
        proxy_read_timeout 60;
        proxy_send_timeout 60;
        proxy_connect_timeout 60;
      '';
    };

    "mgmt.peira.plan.ai" = h {
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
  };
}
