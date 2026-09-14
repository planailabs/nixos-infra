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

  networking.firewall.allowedTCPPorts = [ 80 443 3443 ];

  services.nginx.virtualHosts = {
    "hippocampus.plan.ai" = h {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080/";
        proxyWebsockets = true;
      };
      extraConfig = ''
        # Answers stream token by token and the generator on this host runs on
        # CPU, so give a request room and flush as it arrives instead of
        # buffering the whole response.
        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
        proxy_connect_timeout 60;
        proxy_buffering off;
        # Data pools take document uploads (PDFs).
        client_max_body_size 512m;
      '';
    };

    # The dataset store, for a generating backend that is not on this host. A
    # rented GPU fetches graphs over S3, and garage listens on loopback only
    # (./garage.nix). A port of its own rather than a name of its own: no
    # second DNS record, and it keeps the certificate this host already has.
    "hippocampus-s3" = {
      serverName = "hippocampus.plan.ai";
      onlySSL = true;
      useACMEHost = "hippocampus.plan.ai";
      listen = [
        { addr = "0.0.0.0"; port = 3443; ssl = true; }
        { addr = "[::]"; port = 3443; ssl = true; }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:3900";
        # S3 signs the Host header, port included, and garage recomputes the
        # signature from what it receives. $host drops the port and $http_host
        # is whatever the client sent, which gixy rightly refuses; the literal
        # is the one endpoint this listener is reachable on anyway.
        recommendedProxySettings = false;
        extraConfig = ''
          proxy_http_version 1.1;
          proxy_set_header Host "hippocampus.plan.ai:3443";
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          # A dataset goes up in one request, and S3 streams it.
          client_max_body_size 0;
          proxy_request_buffering off;
          proxy_read_timeout 3600;
          proxy_send_timeout 3600;
        '';
      };
    };
  };
}
