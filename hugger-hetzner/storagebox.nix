{ config, pkgs, lib, ... }:

with lib;

{
  # Make the sshfs mount helper (mount.fuse.sshfs) available to systemd's
  # generated mount units.
  system.fsPackages = [ pkgs.sshfs ];

  # Needed for the `allow_other` option so the hugger service (which may run as
  # its own user) can read the mount even though systemd mounts it as root.
  programs.fuse.userAllowOther = true;

  # Hetzner Storage Box mounted over SSHFS at /srv/models. Auth is key-based:
  # the private key is provisioned via the private submodule
  # (see private/hugger-hetzner.nix -> /etc/storagebox/key) and the matching
  # public key must be authorized on the box (account u624368).
  fileSystems."/srv/models" = {
    # Empty path after ':' mounts the account's home dir. (':/' would mount the
    # box's filesystem root, which is owned by root mode 0511 — not listable or
    # writable as the u624368 account.)
    device = "u624368@u624368.your-storagebox.de:";
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
    ];
  };

  # Don't start the archiver until the model store is actually mounted; if the
  # mount fails, hugger stays down rather than writing to the container's disk.
  systemd.services.hugger = {
    after = [ "srv-models.mount" ];
    requires = [ "srv-models.mount" ];
  };
}
