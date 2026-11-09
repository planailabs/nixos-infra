{ config, lib, pkgs, ... }:

# id.webapp.agency, set up like id.plan.ai (logos/zitadel.nix has the why of
# each setting). Its master key, first admin and bootstrap machine user are in
# private/webapp.nix. The instance-level settings logos applied through the
# API (the security policy's impersonation, for the chat's connector) are
# applied here the same way, once: config only seeds a new instance.
let
  domain = "id.webapp.agency";
  port = 8095;
in
{
  services.zitadel = {
    tlsMode = "external";
    masterKeyFile = "/run/credentials/zitadel.service/masterkey";
    settings = {
      Port = port;
      ExternalDomain = domain;
      ExternalPort = 443;
      ExternalSecure = true;
      # Accounts are made by the console, not signed up for.
      DefaultInstance.LoginPolicy.AllowRegister = false;
      # The chat's connector exchanges a user's token for one at a project's
      # audience (RFC 8693).
      DefaultInstance.Features.TokenExchange = true;
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
    # Zitadel 2.71's setup can't create a new instance on 18: migration
    # 34_add_cache_schema makes an unlogged partitioned table, which 18
    # refuses (SQLSTATE 0A000). Logos' instance ran it on 17 before upgrading.
    package = pkgs.postgresql_17;
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
    # The first instance's setup writes the bootstrap machine user's PAT here.
    serviceConfig.StateDirectory = "zitadel";
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
}
