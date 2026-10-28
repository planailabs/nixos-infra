{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# Restic backups of every host's /var, /root, /home and /etc to the Hetzner
# Storage Box: one repository per machine, in a folder named after the host.
#
# The first backup bootstraps itself — generate the restic password and an ssh
# key, register the key on the box with Hetzner's install-ssh-key (plain ssh,
# the box password fed to sshpass) — then initialises the repository.
let
  box = import "${inputs.self.private}/restic.nix";

  stateDir = "/var/lib/restic-backups";
  keyFile = "${stateDir}/ssh/id_ed25519";
  boxPasswordFile = "/etc/restic-backups/box-password";

  # 23 is the Storage Box's SSH/SFTP port (cf. charon/storagebox.nix).
  sshOptions = "-p 23 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${stateDir}/known_hosts";

  bootstrap = pkgs.writeShellScript "restic-storagebox-bootstrap" ''
    set -eu
    PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.openssh pkgs.sshpass ]}

    state=${stateDir}
    key=${keyFile}
    mkdir -p "$state/ssh"
    chmod 700 "$state" "$state/ssh"

    # The repository password. Generated once: lose it and the backups are lost.
    if [ ! -s "$state/password" ]; then
      (umask 077; head -c 32 /dev/urandom | base64 > "$state/password")
    fi

    # The identity this machine uses to reach the box.
    if [ ! -s "$key" ]; then
      ssh-keygen -q -t ed25519 -N "" -C "$(uname -n) restic" -f "$key"
    fi

    authorized() {
      ssh -i "$key" ${sshOptions} -o BatchMode=yes \
        -l ${box.user} ${box.server} version >/dev/null 2>&1
    }

    if ! authorized; then
      echo "restic: ${box.server} does not know this machine yet, installing $key.pub" >&2
      sshpass -f ${boxPasswordFile} ssh ${sshOptions} \
        -o PubkeyAuthentication=no -o PreferredAuthentications=password \
        -l ${box.user} ${box.server} install-ssh-key < "$key.pub"
      authorized || {
        echo "restic: ${box.server} still rejects the key after install-ssh-key" >&2
        exit 1
      }
    fi
  '';
in {
  environment.etc."restic-backups/box-password" = {
    mode = "0400";
    text = box.password;
  };

  services.restic.backups.hetzner = {
    repository = "sftp:${box.user}@${box.server}:${config.networking.hostName}";
    # The bootstrapped password; a restore needs it from the host it came from.
    passwordFile = "${stateDir}/password";
    initialize = true;
    backupPrepareCommand = "exec ${bootstrap}";

    # Only what exists: restic fails a run in which a listed path is missing,
    # and /home is absent where nobody has a home.
    dynamicFilesFrom = ''
      for path in /var /root /home /etc; do
        if [ -e "$path" ]; then echo "$path"; fi
      done
    '';
    # Restic's own cache, and the password and key it backs up with: the
    # repository is the one place those must not end up.
    exclude = [
      "/var/cache/restic-backups-hetzner"
      "/var/lib/restic-backups"
    ];

    extraOptions = [
      "sftp.command='${pkgs.openssh}/bin/ssh -i ${keyFile} ${sshOptions} -l ${box.user} ${box.server} -s sftp'"
    ];

    # A week of dailies, a month of weeklies, half a year of monthlies.
    pruneOpts = [ "--keep-daily 7" "--keep-weekly 4" "--keep-monthly 6" ];

    timerConfig = {
      OnCalendar = "daily";
      # All machines share the box; keep them from starting in the same minute.
      RandomizedDelaySec = "2h";
      Persistent = true;
    };
  };
}
