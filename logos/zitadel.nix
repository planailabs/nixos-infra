{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.zitadel;
  domain = "id.plan.ai";
  port = 8095;
in
{
  config = mkIf cfg.enable {
    services.zitadel = {
      tlsMode = "external";
      masterKeyFile = "/run/credentials/zitadel.service/masterkey";
      settings = {
        Port = port;
        ExternalDomain = domain;
        ExternalPort = 443;
        ExternalSecure = true;
        Database.postgres = {
          Host = "/run/postgresql";
          Port = 5432;
          Database = "zitadel";
          MaxOpenConns = 20;
          MaxIdleConns = 10;
          MaxConnLifetime = "30m";
          MaxConnIdleTime = "5m";
          User = {
            Username = "zitadel";
            SSL.Mode = "disable";
          };
          Admin = {
            ExistingDatabase = "postgres";
            Username = "zitadel";
            SSL.Mode = "disable";
          };
        };
      };
    };

    services.postgresql = {
      enable = true;
      ensureUsers = [{
        name = "zitadel";
        ensureDBOwnership = true;
        ensureClauses = {
          createrole = true;
          createdb = true;
        };
      }];
      ensureDatabases = [ "zitadel" ];
    };

    systemd.services.zitadel = {
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];
      serviceConfig.LoadCredential = [ "masterkey:/etc/zitadel/masterkey" ];
    };

    services.nginx.virtualHosts.${domain} = {
      enableACME = true;
      forceSSL = true;
      http2 = true;
      locations."/" = {
        extraConfig = ''
          grpc_pass grpc://127.0.0.1:${toString port};
          grpc_set_header Host $host;
          grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          grpc_set_header X-Forwarded-Proto $scheme;
          grpc_set_header X-Forwarded-Host $host;
          grpc_read_timeout 300s;
          grpc_send_timeout 300s;
          client_max_body_size 100M;
        '';
      };
    };
  };
}
