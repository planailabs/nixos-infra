{ config, pkgs, lib, ... }:

{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup";

  home-manager.users.obsidian = { config, pkgs, lib, ... }: {
    home.stateVersion = "26.05";

    programs.obsidian = {
      enable = true;
      vaults.knowledge = {
        target = "knowledge";
        # plugin contents (incl. the data.json with the API key) are merged
        # in from private/obsidian.nix where the key is defined.
      };
    };

    # The vault is a git checkout that already tracks
    # `.obsidian/community-plugins.json` (it lists smart-second-brain).
    # Let home-manager's generated file take precedence so the Local REST
    # API plugin is the active set on this host.
    home.file."knowledge/.obsidian/community-plugins.json".force = true;
  };
}
