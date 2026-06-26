{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.matrix-synapse;

  # well-known payloads, materialized as static files on the rootfs instead of
  # being generated inline by nginx `return 200` blocks.
  wellKnownServer = {
    # use 443 instead of the default 8448 port to unite
    # the client-server and server-server port for simplicity
    "m.server" = "${cfg.backend_domain}:443";
  };
  wellKnownClient = {
    "m.homeserver" = { "base_url" = "https://${cfg.backend_domain}"; };
    "m.identity_server" = { "base_url" = "https://${cfg.identity_server}"; };
  };

  # document root laid out so requests to /.well-known/matrix/{server,client}
  # map straight onto files on disk.
  wellKnownRoot = pkgs.linkFarm "matrix-well-known" [
    {
      name = ".well-known/matrix/server";
      path = pkgs.writeText "matrix-well-known-server" (builtins.toJSON wellKnownServer);
    }
    {
      name = ".well-known/matrix/client";
      path = pkgs.writeText "matrix-well-known-client" (builtins.toJSON wellKnownClient);
    }
  ];

  wellKnownDir = "/srv/matrix";

  # FluffyChat web, pinned to our homeserver. presetHomeserver locks the
  # backend so the user can't pick a different server.
  fluffychatConfig = pkgs.writeText "fluffychat-config.json" (builtins.toJSON {
    applicationName = "plan.ai Chat";
    defaultHomeserver = cfg.backend_domain;
    presetHomeserver = cfg.backend_domain;
  });

  fluffychatWeb = pkgs.runCommand "fluffychat-web-planai" { } ''
    cp -r ${pkgs.fluffychat-web} $out
    chmod -R u+w $out
    cp ${fluffychatConfig} $out/config.json
  '';
in
{
  config = mkIf (cfg.enable) {
    # create the well-known folder on the rootfs at ${wellKnownDir}; symlinked
    # to the nix store so it tracks config changes declaratively.
    systemd.tmpfiles.rules = [
      "L+ ${wellKnownDir} - - - - ${wellKnownRoot}"
    ];
    # we explicitly need LC_COLLATE/LC_CTYPE to be C and ensureDatabases doesn't give a damn
    services.postgresql = {
      enable = true;

      ensureUsers = [{
        name = "matrix-synapse";
      }];
    };

    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "register_new_matrix_user" ''
        exec ${cfg.package}/bin/register_new_matrix_user -c ${cfg.configFile} http://[::1]:8008 "$@"
      '')
      (writeShellScriptBin "setup_matrix_db" ''
        echo 'psql -c '"'"' CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse" TEMPLATE template0 LC_COLLATE = "C" LC_CTYPE = "C"; '"'"' ' | su postgres -
      '')
    ];

    services.nginx.virtualHosts = {
      # Reverse proxy for Matrix client-server and server-server communication
      ${cfg.backend_domain} = {
        enableACME = true;
        forceSSL = true;

        # Or do a redirect instead of the 404, or whatever is appropriate for you.
        # But do not put a Matrix Web client here! See the Element web section below.
        locations."/".extraConfig = ''
          return 404;
        '';

        # forward all Synapse API calls (OIDC, etc) to the synapse Matrix homeserver
        locations."/_synapse" = {
          proxyPass = "http://[::1]:8008"; # without a trailing /
        };

        # forward all Matrix API calls to the synapse Matrix homeserver
        locations."/_matrix" = {
          proxyPass = "http://[::1]:8008"; # without a trailing /
        };
      };

      ${cfg.frontend_domain} = {
        enableACME = true;
        forceSSL = true;

        extraConfig = ''
          rewrite ^/admin$ /admin/ permanent;
        '';

        root = pkgs.element-web.override {
          conf = {
            default_server_config."m.homeserver" = {
              "base_url" = "https://${cfg.backend_domain}";
              "server_name" = "${cfg.settings.server_name}";
            };
          };
        };

        locations."/admin/" = {
          alias = "${pkgs.synapse-admin-etkecc.withConfig({
            restrictBaseUrl = "https://${cfg.backend_domain}";
          })}/";
        };
      };

      # FluffyChat web client, hard-wired to our homeserver
      ${cfg.fluffy_domain} = {
        enableACME = true;
        forceSSL = true;

        root = "${fluffychatWeb}";

        # Flutter web is a SPA; route unknown paths back to index.html
        locations."/".tryFiles = "$uri $uri/ /index.html";
      };
    };

    services.matrix-synapse = {
      withJemalloc = true;

      # secret lives in the private submodule (private/<host>.nix)
      settings.registration_shared_secret = cfg.registrationSharedSecret;

      # no username/password login and no password registration; accounts are
      # only created/authenticated through the Google OIDC provider below.
      # (SSO auto-provisions users regardless of enable_registration.)
      settings.enable_registration = false;
      settings.password_config.enabled = false;

      settings.public_baseurl = "https://${cfg.backend_domain}/";

      settings.oidc_providers = [
        {
          idp_id = "google";
          idp_name = "Google";
          idp_brand = "google";

          issuer = "https://accounts.google.com/";
          discover = true;

          # credentials live in the private submodule (private/<host>.nix)
          client_id = cfg.sso.clientId;
          client_secret = cfg.sso.clientSecret;

          scopes = [
            "openid"
            "profile"
            "email"
          ];

          user_mapping_provider = {
            config = {
              # Google does not provide preferred_username; derive it from email
              localpart_template = "{{ user.email.split('@')[0] }}";
              display_name_template = "{{ user.name }}";
              email_template = "{{ user.email }}";
            };
          };
        }
      ];

      # the federated identity domain; defaults to the host name (logos)
      # otherwise, so pin it to the public domain
      settings.server_name = "plan.ai";

      settings.listeners = [
        {
          port = 8008;
          bind_addresses = [
            "::1"
          ];

          type = "http";
          tls = false;
          x_forwarded = true;

          resources = [
            {
              names = [ "client" "federation" ];
              compress = false;
            }
          ];
        }
      ];
    };
  };

  options = {
    services.matrix-synapse = {
      backend_domain = mkOption {
        type = types.str;
        description = "Backend serivces (synapse) domain for matrix";
        default = "synapse.plan.ai";
      };

      frontend_domain = mkOption {
        type = types.str;
        description = "Frontend serivces (element) domain for matrix";
        default = "matrix.plan.ai";
      };

      fluffy_domain = mkOption {
        type = types.str;
        description = "FluffyChat web client domain for matrix";
        default = "fluffy.plan.ai";
      };

      identity_server = mkOption {
        type = types.str;
        description = "Identity server";
        default = "vector.im";
      };

      registrationSharedSecret = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Matrix registration shared secret (set in the private submodule)";
      };

      sso = {
        clientId = mkOption {
          type = types.str;
          description = "Google OAuth client ID for Matrix SSO (set in the private submodule)";
        };

        clientSecret = mkOption {
          type = types.str;
          description = "Google OAuth client secret for Matrix SSO (set in the private submodule)";
        };
      };
    };
  };
}
