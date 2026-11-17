{ config, lib, pkgs, ... }:

# Zitadel's Login v2 (pkgs.zitadel-login, patched: pkgs/zitadel-login) next to
# the Zitadel of this host, at https://<ExternalDomain>/ui/v2/login (the base
# path is built in). The instance sends sign-ins there once its loginV2
# feature points at it:
#   PUT /v2/features/instance {"loginV2": {"required": true, "baseUri": "https://<domain>/ui/v2/login"}}
# Turning the feature off is the way back to the v1 login, which stays served.
#
# /etc/zitadel-login/env holds ZITADEL_SERVICE_USER_TOKEN: the PAT of the
# machine user "login-client" (instance role IAM_LOGIN_CLIENT), from private/.
let
  zitadel = config.services.zitadel;
  domain = zitadel.settings.ExternalDomain;
  port = 8098;
in
{
  config = lib.mkIf zitadel.enable {
    systemd.services.zitadel-login = {
      description = "ZITADEL login (v2)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "zitadel.service" ];
      wants = [ "network-online.target" ];
      environment = {
        HOSTNAME = "127.0.0.1";
        PORT = toString port;
        # Straight to Zitadel. Node's fetch won't send a different Host, so
        # the instance comes from x-zitadel-instance-host instead.
        ZITADEL_API_URL = "http://127.0.0.1:${toString zitadel.settings.Port}";
        CUSTOM_REQUEST_HEADERS = "x-zitadel-instance-host:${domain},x-zitadel-public-host:${domain}";
        NEXT_TELEMETRY_DISABLED = "1";
      };
      serviceConfig = {
        ExecStart = lib.getExe pkgs.zitadel-login;
        EnvironmentFile = "/etc/zitadel-login/env";
        DynamicUser = true;
        Restart = "on-failure";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };

    services.nginx.virtualHosts.${domain}.locations."/ui/v2/login" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      # Host and X-Forwarded-*, once: the login builds its URLs from them, and a
      # doubled X-Forwarded-Host ("a, a") makes every redirect an invalid URL.
      recommendedProxySettings = true;
    };
  };
}
