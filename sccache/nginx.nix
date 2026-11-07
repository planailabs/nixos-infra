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
        # S3 signs the body; stream it as is.
        extraConfig = ''
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
