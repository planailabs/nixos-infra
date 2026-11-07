{ ... }:

{
  services.nginx = {
    enable = true;
    enableReload = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."sccache.plan.ai" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:3900";
        # S3 signs the Host header as the client sent it, port included (the
        # CI sandbox bridge sends 127.0.0.1:7714), so pass it on untouched.
        recommendedProxySettings = false;
        # S3 signs the body; stream it as is.
        extraConfig = ''
          proxy_set_header Host $http_host;
          client_max_body_size 0;
          proxy_request_buffering off;
          proxy_buffering off;
          proxy_read_timeout 600;
          proxy_send_timeout 600;
        '';
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
