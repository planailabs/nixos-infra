{ config, lib, pkgs, ... }:

let
  garage = config.services.garage.package;
  # Objects are sccache entries: dropping old ones only costs a recompile.
  expireDays = 30;
  lifecycle = pkgs.writeText "sccache-lifecycle.json" (builtins.toJSON {
    Rules = [{
      ID = "expire";
      Status = "Enabled";
      Filter = { Prefix = ""; };
      Expiration = { Days = expireDays; };
    }];
  });
in
{
  services.garage = {
    enable = true;
    package = pkgs.garage_2;
    # GARAGE_RPC_SECRET, GARAGE_ADMIN_TOKEN, and the sccache keys used by
    # garage-init (SCCACHE_{RW,RO,EXT}_KEY_{ID,SECRET}).
    environmentFile = "/etc/garage.env";
    settings = {
      replication_factor = 1;
      db_engine = "sqlite";
      metadata_dir = "/var/lib/garage/meta";
      data_dir = "/srv/garage";
      rpc_bind_addr = "127.0.0.1:3901";
      rpc_public_addr = "127.0.0.1:3901";
      s3_api = {
        s3_region = "garage";
        api_bind_addr = "127.0.0.1:3900";
      };
      admin.api_bind_addr = "127.0.0.1:3903";
    };
  };

  systemd.services.garage = {
    after = [ "srv-garage.mount" ];
    requires = [ "srv-garage.mount" ];
  };

  # One node, one bucket, three keys: read-write for protected CI pipelines,
  # read-only for other CI jobs, read-write for use outside CI (workstations). Idempotent; runs after every start.
  systemd.services.garage-init = {
    after = [ "garage.service" ];
    requires = [ "garage.service" ];
    wantedBy = [ "garage.service" ];
    path = [ garage pkgs.awscli2 pkgs.gnugrep pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "/etc/garage.env";
    };
    script = ''
      set -eu
      until garage status >/dev/null 2>&1; do sleep 1; done

      if garage layout show | grep -q 'No nodes currently have a role'; then
        garage layout assign -z dc1 -c 5TB "$(garage node id -q | cut -d@ -f1)"
        garage layout apply --version 1
      fi

      garage bucket info sccache >/dev/null 2>&1 || garage bucket create sccache
      # Same bucket for clients outside CI: their endpoint is sccache.plan.ai,
      # and the S3 client strips a leading "<bucket>." from the endpoint
      # (virtual-host style), which would send bucket "sccache" to plan.ai.
      garage bucket info cache >/dev/null 2>&1 || garage bucket alias sccache cache
      garage key info "$SCCACHE_RW_KEY_ID" >/dev/null 2>&1 \
        || garage key import --yes -n sccache-rw "$SCCACHE_RW_KEY_ID" "$SCCACHE_RW_KEY_SECRET"
      garage key info "$SCCACHE_RO_KEY_ID" >/dev/null 2>&1 \
        || garage key import --yes -n sccache-ro "$SCCACHE_RO_KEY_ID" "$SCCACHE_RO_KEY_SECRET"
      garage key info "$SCCACHE_EXT_KEY_ID" >/dev/null 2>&1 \
        || garage key import --yes -n sccache-ext "$SCCACHE_EXT_KEY_ID" "$SCCACHE_EXT_KEY_SECRET"
      garage bucket allow --read --write sccache --key "$SCCACHE_RW_KEY_ID"
      garage bucket allow --read --write sccache --key "$SCCACHE_EXT_KEY_ID"
      garage bucket allow --read sccache --key "$SCCACHE_RO_KEY_ID"

      # Setting the lifecycle needs owner rights, which CI keeps no longer than that.
      trap 'garage bucket deny --owner sccache --key "$SCCACHE_RW_KEY_ID"' EXIT
      garage bucket allow --owner sccache --key "$SCCACHE_RW_KEY_ID"
      AWS_ACCESS_KEY_ID=$SCCACHE_RW_KEY_ID AWS_SECRET_ACCESS_KEY=$SCCACHE_RW_KEY_SECRET \
        aws --endpoint-url http://127.0.0.1:3900 --region garage \
        s3api put-bucket-lifecycle-configuration --bucket sccache \
        --lifecycle-configuration file://${lifecycle}
    '';
  };
}
