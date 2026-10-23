{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.hedgedoc;

  # This is a team wiki, not a public notes service: nothing on it should be
  # reachable by, or creatable by, unauthenticated visitors. Upstream's views
  # hardcode the stock "HedgeDoc - Ideas grow better together" title (no config
  # key for it in 1.12), so carry a copy with our name in it.
  siteTitle = "plan.ai Docs";
  siteTagline = "Team wiki";
  views = pkgs.runCommand "hedgedoc-views-planai" { } ''
    cp -r ${pkgs.hedgedoc}/share/hedgedoc/public/views $out
    chmod -R u+w $out
    ${pkgs.gnused}/bin/sed -i \
      -e 's/HedgeDoc - Ideas grow better together/${siteTitle}/g' \
      -e 's/Ideas grow better together/${siteTagline}/g' \
      $(find $out -name '*.ejs')
  '';
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

      # Anonymous note creation and anonymous uploads off. Sign-in is the
      # Google OAuth the instance is already wired for (private submodule:
      # plan.ai hosted domain) — `/new` now bounces to the Google consent
      # screen. HedgeDoc 1.12 has no OIDC client (only generic OAuth2 without
      # discovery), so pointing it at Zitadel would need a new Zitadel app.
      allowAnonymous = false;
      allowAnonymousEdits = false;
      # 'all' let any visitor upload, and the allow-list includes
      # image/svg+xml — attacker HTML on the docs.plan.ai origin.
      enableUploads = "registered";

      viewPath = views;
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
