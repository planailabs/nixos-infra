# From mgit-at/nixos-common (modules/ansible-host.nix, master, fetched 2026-11-09):
# /usr/bin/python3 for ansible, which expects a Python there on its targets.
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.ansible-host;
in
{
  options.ansible-host = {
    enable = mkEnableOption "ansible support on host" // { default = true; };
    extraPyPackages = mkOption {
      description = "Extra python packages";
      type = types.listOf types.str;
      default = [];
    };
  };

  config = mkIf (cfg.enable) {
    systemd.tmpfiles.rules = with pkgs; [
      "L+ /usr/bin/python3 - - - - ${pkgs.python3.withPackages(ps: map (pkg: ps.${pkg}) cfg.extraPyPackages)}/bin/python3"
    ];
  };
}
