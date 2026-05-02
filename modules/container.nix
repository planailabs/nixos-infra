{ modulesPath, lib, ... }: with lib; {
  imports = [
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];

  # nix-channel-init.service comes from the installer-image module (imported
  # via lxc-container.nix), gated on this option (not nix.channel.enable). It
  # re-runs every boot when /var/lib/nixos/did-channel-init is missing, and
  # its `ln -s` (no -f) fails on hosts where /root/.nix-defexpr/channels
  # already exists.
  system.installer.channel.enable = false;
  # TODO: set those properly with the right prio
  security.audit.enable = mkOverride 1 false; # common and container, common should have lower prio
  security.auditd.enable = mkOverride 1 false; # common and container, common should have lower prio

  nix.optimise.automatic = true;

  # networking
  networking.nftables.enable = true;

  # networkd
  networking.useNetworkd = mkForce true;
  networking.dhcpcd.enable = mkForce false;
  services.resolved.dnssec = "false";
  systemd.network.wait-online.enable = false;

  # don't do dhcp everywhere
  networking.useDHCP = mkForce false;
  # just on eth0
  networking.interfaces.eth0.useDHCP = true;

  networking.resolvconf.enable = false;
  networking.useHostResolvConf = false;

  # services.resolved.enable = mkForce false;
  # networking.useHostResolvConf = mkForce false;
  # networking.dhcpcd.enable = mkForce true;
  # networking.dhcpcd.persistent = mkForce true;
  # networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];
}

