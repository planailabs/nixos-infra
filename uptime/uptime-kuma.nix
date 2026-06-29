{ ... }:

{
  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "127.0.0.1";
      # nginx (./nginx.nix) reverse-proxies uptime.plan.ai to this port
      PORT = "3636";
    };
  };
}
