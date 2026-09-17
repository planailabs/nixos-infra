{ config, pkgs, lib, ... }:

with lib;

{
  services.transmission = {
    enable = true;
    package = pkgs.transmission_4;

    # rpc-username / rpc-password live outside the store; the module jq-merges
    # this file over the generated settings.json on every start.
    credentialsFile = "/etc/transmission/credentials.json";

    # Inbound BitTorrent peers need to reach us, so open the peer port. The RPC
    # port is deliberately NOT opened here -- see the yggdrasil-only rule below.
    openPeerPorts = true;
    openRPCPort = false;

    settings = {
      # All torrent data lives on the Hetzner Storage Box (see ./storagebox.nix);
      # this instance only has a 38G root disk. Transmission's own state
      # (settings, resume/.torrent files) stays on local disk under
      # /var/lib/transmission -- sqlite-ish resume writes over SSHFS are slow
      # and corrupt easily on a dropped connection.
      download-dir = "/storage/torrents/complete";
      incomplete-dir = "/storage/torrents/incomplete";
      incomplete-dir-enabled = true;
      watch-dir = "/storage/torrents/watch";
      watch-dir-enabled = true;

      # Never preallocate: over SSHFS "full" writes the whole file's worth of
      # zeros across the WAN, and the box doesn't give us real sparse files for
      # "fast" either. Let the file grow as pieces land.
      preallocation = 0;

      rpc-port = 9091;
      # Listen on all addresses; reachability is constrained by nftables to the
      # yggdrasil mesh only (below).
      rpc-bind-address = "::";
      rpc-authentication-required = true;
      # Transmission's whitelists match on literal globs and can't express an
      # IPv6 prefix like 200::/7, so the mesh restriction is enforced in the
      # firewall instead of here. The host whitelist would likewise reject the
      # IPv6-literal Host header used to reach the web UI.
      rpc-whitelist-enabled = false;
      rpc-host-whitelist-enabled = false;

      peer-port = 51413;
      utp-enabled = true;
      encryption = 2;                      # require encrypted peer connections
      dht-enabled = true;
      pex-enabled = true;
      lpd-enabled = false;                 # no local peers on a cloud instance

      # 2 GiB of RAM total; keep transmission's cache modest.
      cache-size-mb = 64;
      peer-limit-global = 200;
      peer-limit-per-torrent = 50;
    };
  };

  # Web UI / RPC is reachable only over the yggdrasil mesh (0200::/7), like the
  # other internal services here. Nothing is exposed publicly and there is no
  # nginx/ACME vhost for this host.
  networking.firewall.extraInputRules = ''
    ip6 saddr 200::/7 tcp dport 9091 accept
  '';

  # The download dirs are on the SSHFS mount, and the unit bind-mounts them into
  # its RootDirectory=, so it cannot start before /storage is there. If the box
  # is unreachable transmission stays down rather than silently filling the
  # 38G root disk.
  systemd.services.transmission = {
    after = [ "storage.mount" ];
    requires = [ "storage.mount" ];
  };
}
