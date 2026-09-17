{ config, pkgs, lib, ... }:

with lib;

{
  # Make the sshfs mount helper (mount.fuse.sshfs) available to systemd's
  # generated mount units.
  system.fsPackages = [ pkgs.sshfs ];

  # Needed for `allow_other`, so the transmission user (and systemd, which sets
  # the mount up as root) can both traverse the mount.
  programs.fuse.userAllowOther = true;

  # Hetzner Storage Box sub-account u624368-sub1, mounted over SSHFS at
  # /storage. Auth is key-based: the private key comes from the private
  # submodule (private/charon.nix -> /etc/storagebox/key) and its public half
  # is authorized in the sub-account's ~/.ssh/authorized_keys:
  #   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICjSPGRBSOvvF+znstHO38Zygug9GQSoeozFmRTvVciL charon storagebox u624368-sub1
  fileSystems."/storage" = {
    # Empty path after ':' mounts the sub-account's home dir. (':/' would mount
    # the box's filesystem root, which is root-owned mode 0511 -- not listable
    # or writable as the sub-account.)
    device = "u624368-sub1@u624368.your-storagebox.de:";
    fsType = "fuse.sshfs";
    options = [
      "_netdev"
      "allow_other"
      "reconnect"
      "ServerAliveInterval=15"
      "ServerAliveCountMax=3"
      "port=23"                            # Hetzner Storage Box SSH/SFTP port
      "IdentityFile=/etc/storagebox/key"
      "StrictHostKeyChecking=accept-new"
      # The box reports its own uid/gid (u624368-sub1), which means nothing
      # locally, so present everything as transmission:transmission (uid/gid 70,
      # config.ids.{uids,gids}.transmission). Without this the daemon cannot
      # write to its own download dir.
      "uid=${toString config.ids.uids.transmission}"
      "gid=${toString config.ids.gids.transmission}"
      # Larger read chunks for the big sequential transfers torrent data makes;
      # the default splits them into many small SFTP round-trips over the WAN.
      # (No "big_writes" -- libfuse3 dropped the option and always does it.)
      "max_read=65536"
    ];
  };
}
