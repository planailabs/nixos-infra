{ modulesPath, lib, ... }: with lib; {
  imports = [
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];
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

