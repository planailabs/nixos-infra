# Migrate the live Postgres clusters from major 17 to the nixpkgs default (18)
# with pg_upgrade on first start, the way nixpkgs#129285 proposes. The package
# follows the nixpkgs artifact, so the major already moved once (2026-10-11) and
# started an empty /var/lib/postgresql/18 next to the real 17 cluster
# (topics/postgres-17-to-18-incident-2026-10-11.md). The 17 directory is left in
# place as the rollback copy; drop this module once every host has upgraded.
{ config, lib, pkgs, ... }:
let
  inherit (config.services.postgresql) superUser;
  old = "/var/lib/postgresql/17";
in
{
  systemd.services.postgresql = {
    # Before the module's own initdb: a missing PG_VERSION plus an existing 17
    # cluster means "migrate", not "fresh cluster".
    preStart = lib.mkBefore ''
      if [ ! -e "$PGDATA/PG_VERSION" ] && [ -e ${old}/PG_VERSION ]; then
        echo "postgres: pg_upgrade ${old} -> $PGDATA"
        # 17 was initdb'd without data checksums, 18's initdb enables them by
        # default, and pg_upgrade refuses the mismatch.
        initdb --no-data-checksums -U ${superUser} ${lib.escapeShellArgs config.services.postgresql.initdbArgs}
        work=$(mktemp -d)
        if ! ( cd "$work" && pg_upgrade -U ${superUser} \
            -b ${pkgs.postgresql_17}/bin -B ${config.services.postgresql.finalPackage}/bin \
            -d ${old} -D "$PGDATA" --socketdir="$work" ); then
          # A half-upgraded cluster must never look initialised: the next start
          # would serve it empty. Keep it for inspection and let the service
          # start retry the upgrade from the untouched 17 copy.
          mv "$PGDATA" "/var/lib/postgresql/18-failed-$(date +%Y%m%dT%H%M%S)"
          mkdir -m 0700 "$PGDATA"
          exit 1
        fi
      fi
    '';

    # pg_upgrade has to start both clusters; the module's 120 s stop timeout and
    # the matching start limit are too short for a multi-GB copy.
    serviceConfig.TimeoutStartSec = "3600";
    unitConfig.StartLimitIntervalSec = lib.mkForce (6 * 3600);

    # The old cluster stays read-only for the service; pg_upgrade only needs to
    # start it, which writes postmaster.pid into ${old}.
    serviceConfig.ReadWritePaths = [ old ];
  };
}
