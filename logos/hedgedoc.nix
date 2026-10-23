{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.hedgedoc;

  # This is a team wiki, not a public notes service: nothing on it should be
  # reachable by, or creatable by, unauthenticated visitors. Upstream's views
  # hardcode the stock "HedgeDoc - Ideas grow better together" title (no config
  # key for it in 1.12), so carry a copy with our name in it.
  #
  # viewPath is a views *root*: some routes render paths that climb out of it
  # (`res.render("../js/lib/common/constant.ejs")` serves /config), so the copy
  # keeps the public/ layout by symlinking every sibling of views/ rather than
  # pointing viewPath at a bare views copy — that 500s /config.
  siteTitle = "plan.ai Docs";
  siteTagline = "Team wiki";
  views = pkgs.runCommand "hedgedoc-views-planai" { } ''
    mkdir -p $out
    cp -r ${pkgs.hedgedoc}/share/hedgedoc/public/views $out/views
    chmod -R u+w $out/views
    ${pkgs.gnused}/bin/sed -i \
      -e 's/HedgeDoc - Ideas grow better together/${siteTitle}/g' \
      -e 's/Ideas grow better together/${siteTagline}/g' \
      $(find $out/views -name '*.ejs')
    for sibling in ${pkgs.hedgedoc}/share/hedgedoc/public/*; do
      name=$(basename "$sibling")
      [ "$name" = views ] || ln -s "$sibling" "$out/$name"
    done
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

      viewPath = "${views}/views";

      # HedgeDoc ships its own helmet HSTS (one year) and Referrer-Policy
      # (same-origin), and nginx adds the estate-wide pair on top. A browser
      # that sees two STS headers must ignore both (RFC 6797 §8.1), so leave
      # HSTS to nginx alone; HedgeDoc's Referrer-Policy is the stricter of the
      # two and is kept (nginx's is dropped for this location below).
      hsts.enable = false;
    };

    services.nginx.virtualHosts."${cfg.settings.domain}" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://[::1]:34223";
        proxyWebsockets = true;
        # Any add_header here drops the http-level set, so repeat what must
        # survive and omit Referrer-Policy: HedgeDoc already sends that one.
        extraConfig = ''
          add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;
          add_header X-Content-Type-Options nosniff always;
          add_header Content-Security-Policy "frame-ancestors 'none'" always;
        '';
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
