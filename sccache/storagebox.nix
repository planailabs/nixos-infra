{ pkgs, ... }:

{
  system.fsPackages = [ pkgs.sshfs ];
  # Garage runs as a DynamicUser; systemd mounts the box as root.
  programs.fuse.userAllowOther = true;

  # Same Storage Box (and key) as hugger-hetzner, in a dot-dir hugger's
  # model listing skips. Only Garage's data blocks live here; its metadata
  # (sqlite) stays on local disk, since locking over sshfs isn't safe.
  fileSystems."/srv/garage" = {
    device = "u624368@u624368.your-storagebox.de:.sccache-garage";
    fsType = "fuse.sshfs";
    options = [
      "_netdev"
      "allow_other"
      "reconnect"
      "ServerAliveInterval=15"
      "ServerAliveCountMax=3"
      "port=23"
      "IdentityFile=/etc/storagebox/key"
      "StrictHostKeyChecking=accept-new"
    ];
  };
}
