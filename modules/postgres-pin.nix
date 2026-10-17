# Hold the live Postgres clusters on major 17. The postgresql package follows
# the nixpkgs artifact, and 18 would start an empty /var/lib/postgresql/18 (the
# data dir follows the major version) next to the real 17 cluster, silently
# (topics/postgres-17-to-18-incident-2026-10-11.md). Delete this once the hosts
# are migrated with a planned pg_upgrade.
{ lib, pkgs, ... }:
{
  services.postgresql.package = lib.mkForce pkgs.postgresql_17;
}
