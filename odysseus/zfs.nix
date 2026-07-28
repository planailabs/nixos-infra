{ pkgs, ... }: {
  /* services.syncoid = {
    enable = true;
    localSourceAllow = [ "allow" "clone" "create" "destroy" "diff" "hold" "mount" "promote" "receive" "release" "rename" "rollback" "send" "share" "snapshot" ];
    localTargetAllow = [ "allow" "clone" "create" "destroy" "diff" "hold" "mount" "promote" "receive" "release" "rename" "rollback" "send" "share" "snapshot" ];
    # user = "root";
    # group = "wheel";
    commands.root = {
      source = "omen";
      target = "omen-hdd/backup";
      recursive = true;
      extraArgs = [ "--preserve-properties" "--delete-target-snapshots" "--no-sync-snap" "--force-delete" ];
    };
  }; */

  services.sanoid = {
    enable = true;
    datasets."omen" = {
      hourly = 6;
      daily = 2;
      monthly = 0;
      yearly = 0;
      # processChildrenOnly = true;
      recursive = true;
      autosnap = true;
      autoprune = true;
    };
  };

  systemd.services.syncoid-root = {
    serviceConfig.ExecStart = "${pkgs.sanoid}/bin/syncoid -r --preserve-properties --delete-target-snapshots --no-sync-snap --force-delete omen omen-hdd/backup";
    startAt = "*-*-* *:30:00"; # 30mins past sanoid
  };
}

