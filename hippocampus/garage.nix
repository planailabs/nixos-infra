{ config, lib, pkgs, ... }:

with lib;

{
  # The dataset store both hippocampus halves talk to. It is S3 by design --
  # "exactly one store, so a dataset is never in two places" -- and a
  # single-node garage on the same host is that store without dragging in an
  # external provider or its credentials.
  services.garage = {
    enable = true;
    package = pkgs.garage_2;
    # Carries GARAGE_RPC_SECRET; see private/hippocampus.nix for why it is not
    # in the settings below.
    environmentFile = "/etc/garage.env";
    settings = {
      db_engine = "lmdb";
      # One node: there is nowhere to replicate to.
      replication_factor = 1;
      # Loopback only. Nothing outside this container speaks to garage --
      # nginx fronts hippocampus, not the object store.
      rpc_bind_addr = "[::1]:3901";
      rpc_public_addr = "[::1]:3901";
      s3_api = {
        api_bind_addr = "127.0.0.1:3900";
        # Arbitrary, but the client has to sign with the same one: see
        # services.hippocampus.*.store.region in ./default.nix.
        s3_region = "garage";
        root_domain = ".s3.garage";
      };
    };
  };

  # A garage node stores nothing until the layout gives it a role, and the
  # bucket and key have to exist before either service can read the store.
  # Every step is guarded, so this is a no-op on an already-initialised node.
  systemd.services.garage-hippocampus-init = {
    description = "Give garage its layout, bucket and S3 key";
    after = [ "garage.service" ];
    requires = [ "garage.service" ];
    wantedBy = [ "multi-user.target" ];
    # The S3 key imported here is the one the services authenticate with, so it
    # is read from the same file they get it from rather than defined twice.
    path = [ config.services.garage.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = [ "/etc/garage.env" "/etc/hippocampus.env" ];
    };
    script = ''
      set -eu

      # `garage server` forks before its RPC socket answers, so poll.
      for _ in $(seq 1 60); do
        garage status >/dev/null 2>&1 && break
        sleep 1
      done

      if garage status | grep -q 'NO ROLE ASSIGNED'; then
        node="$(garage node id -q | cut -d@ -f1)"
        garage layout assign -z plan-ai -c 100G "$node"
        # `layout show` prints the command to commit the staged change,
        # including the version number to pass -- take it from there rather
        # than tracking it ourselves.
        version="$(garage layout show | sed -n 's/.*--version \([0-9]\+\).*/\1/p' | tail -n1)"
        garage layout apply --version "$version"
      fi

      garage bucket info hippocampus >/dev/null 2>&1 || garage bucket create hippocampus
      garage key info "$S3_ACCESS_KEY" >/dev/null 2>&1 ||
        garage key import --yes -n hippocampus "$S3_ACCESS_KEY" "$S3_SECRET_KEY"
      # Idempotent, and cheap enough to reassert on every boot.
      garage bucket allow --read --write --owner hippocampus --key "$S3_ACCESS_KEY"
    '';
  };
}
