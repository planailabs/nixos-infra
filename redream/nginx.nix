{ ... }:

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

  services.nginx.virtualHosts."redream.plan.ai" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8088";
      proxyWebsockets = true;
      # The VNC console is a long-lived websocket.
      extraConfig = ''
        proxy_read_timeout 1d;
        proxy_send_timeout 1d;
      '';
    };
  };
}
