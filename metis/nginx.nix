{ config, pkgs, lib, ... }:

with lib;

let
  h = a: a // {
    forceSSL = true;
    useACMEHost = "extra-skills.plan.ai";
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

  security.acme.certs."extra-skills.plan.ai" = {
    domain = "extra-skills.plan.ai";
    extraDomainNames = [ "*.extra-skills.plan.ai" ];
    group = "nginx";
    webroot = "/var/lib/acme/acme-challenge";
  };

  services.nginx.virtualHosts = {
    "xzar.extra-skills.plan.ai" = h {
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

    "api.extra-skills.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://localhost:7378/";
      };
      extraConfig = ''
        proxy_read_timeout 60;
        proxy_send_timeout 60;
        proxy_connect_timeout 60;
      '';
    };

    "mgmt.extra-skills.plan.ai" = h {
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
