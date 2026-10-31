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
        # Self-registration is not a product feature (accounts are provisioned
        # by the cloud console), so it stays closed. This seeds the login policy
        # of the first and of any new virtual instance; password login stays on.
        # The live instance's policy row was set to allowRegister=false through
        # the Admin API on 2026-10-28, since config only seeds new instances:
        #   GET  /admin/v1/policies/login
        #   PUT  /admin/v1/policies/login   (same body, "allowRegister": false)
        #
        # EXPLICIT EXEMPTION: the "plan.ai" org (397597061693833352) has its own
        # login policy with open sign-up through social logins only, for
        # chat.plan.ai's public users (sign-in there is limited to this org).
        # allowRegister=true, allowUsernamePassword=false, passwordless off,
        # external IdPs on with GitHub (397597815963910280, auto-creation) as
        # the only one. Set 2026-10-31 through the Management API (org scope):
        #   PUT /management/v1/policies/login   (x-zitadel-orgid: 397597061693833352)
        # Every other org, and the instance default, stay closed.
        DefaultInstance.LoginPolicy.AllowRegister = false;
        # chat.plan.ai's connector exchanges a signed-in user's token for an
        # access token of that user, scoped to a target project's audience
        # (RFC 8693, Zitadel's impersonation flavour). Two instance settings
        # are needed, both IAM-level and both applied to the live instance on
        # 2026-10-31 with the instance-admin PAT:
        #   PUT /v2/features/instance  {"oidcTokenExchange": true}
        #   PUT /v2/policies/security  {"enableImpersonation": true}
        # Only the feature has a config key (InstanceSetup.Features), so that
        # is the one seeded here. 2.71.7 has no security-policy config key at
        # all; its v1 equivalent is PUT /admin/v1/policies/security, which
        # replaces the whole policy, so GET it first and merge.
        # Like AllowRegister above, config seeds a NEW instance only; a running
        # instance keeps its feature and policy rows in Postgres.
        # Verifying: GET /v2/features/instance shows oidcTokenExchange.enabled
        # and GET /v2/settings/security shows enableImpersonation. The
        # discovery document is no use — it never lists the token-exchange
        # grant in 2.71.7, enabled or not, because the OIDC library only
        # advertises it when the storage type implements its
        # TokenExchangeStorage while Zitadel implements the exchange on its own
        # server type. A POST to /oauth/v2/token with the grant and a bogus
        # client_id only proves the build dispatches the grant (invalid_client
        # rather than unsupported_grant_type); it answers invalid_client with
        # the feature off too.
        # The connector's OIDC app must also list the token-exchange grant type,
        # and its service account still needs IAM_ADMIN_IMPERSONATOR (plan.ai
        # makes every customer ORG_OWNER of their org, and the
        # *_END_USER_IMPERSONATOR roles only cover users without memberships).
        # That role can also impersonate instance admins: its key is root-grade.
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
