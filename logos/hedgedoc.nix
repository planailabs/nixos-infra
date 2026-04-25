{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.hedgedoc;
in
{
  config = mkIf cfg.enable {
    services.hedgedoc.settings = {
      db = {
        dialect = "postgres";
        host = "/run/postgresql";
      };
      host = "::1";
      port = 34223;
      protocolUseSSL = true;
      email = false;
      allowEmailRegister = false;
    };

    services.nginx.virtualHosts."${cfg.settings.domain}" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://[::1]:34223";
        proxyWebsockets = true;
      };
    };

    systemd.services.hedgedoc = {
      requires = [ "postgresql.service" ];
    };

    services.postgresql = {
      enable = true;

      ensureUsers = [{
        name = "hedgedoc";
        ensureDBOwnership = true;
      }];
      ensureDatabases = [ "hedgedoc" ];
    };
  };
}
