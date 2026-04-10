{ config, pkgs, lib, inputs, ... }:

with lib;

{
  imports =
    [
      inputs.hardware.nixosModules.raspberry-pi-3
    ];
  hardware = {
    raspberry-pi."4".apply-overlays-dtmerge.enable = true;
    deviceTree = {
      enable = true;
      filter = "*rpi-4-*.dtb";
    };
  };
#  console.enable = false;
  environment.systemPackages = with pkgs; [
    libraspberrypi
    raspberrypi-eeprom
  ];
  
  # Basic networking
  networking.networkmanager.enable = true;
  # Prevent host becoming unreachable on wifi after some time.
  networking.networkmanager.wifi.powersave = false;
  # Prevent wait-online service from waiting forever
  systemd.network.enable = mkForce false;

  #system.autoUpgrade.enable = true;
  #system.autoUpgrade.allowReboot = true;
  #system.autoUpgrade.rebootWindow.lower = "02:00";
  #system.autoUpgrade.rebootWindow.upper = "08:00";
  #system.autoUpgrade.flake = "git+ssh://git@git.mkg20001.io/mkg20001/raupe";
}
