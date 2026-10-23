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
    "codex.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080/";
        proxyWebsockets = true;
      };
      # LiteLLM publishes its Swagger UI at / and /docs, /redoc, /openapi.json,
      # and reports the database attachment on /health/readiness. The gateway is
      # meant to be reachable without a portal, but its API documentation and
      # readiness oracle are not: drop them. `/` keeps answering 200 — it is
      # what the uptime monitor on this name watches — but with the liveness
      # answer instead of the docs.
      locations."= /".proxyPass = "http://127.0.0.1:8080/health/liveliness";
      locations."= /docs".return = "404";
      locations."= /docs/oauth2-redirect".return = "404";
      locations."= /redoc".return = "404";
      locations."= /openapi.json".return = "404";
      locations."= /health/readiness".return = "404";
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
