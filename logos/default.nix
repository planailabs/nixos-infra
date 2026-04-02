{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/logos.nix"
    ./nginx.nix
  ];

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  systemd.network = {
    networks."40-public0" = {
      matchConfig = {
        Name = "public0";
      };
      gateway = [ "65.108.140.193" ];
      addresses = [
        { addressConfig = { Address = "65.108.140.230/26"; Peer = "65.108.140.193"; }; }
      ];
    };
  };

  mkg.mod = {
    yggdrasil = {
      enable = true;
      port = 14466;
      peers = [ "tcp://ygg.mkg20001.io:80" "tls://ygg.mkg20001.io:443" ];
    };
  };

  services.xzar-server = {
    enable = true;
  };

  services.acme-distributor = {
    enable = true;
  };

  services.mac-mgmt-server = {
    enable = true;
  };

  services.plan-ai-chat = {
    enable = true;
    package = pkgs.plan-ai-chat.override {
      envVars = {
        VITE_SUPABASE_URL = "https://tlssdiqdokctvxcezptr.supabase.co";
        VITE_SUPABASE_PUBLISHABLE_KEY = "sb_publishable_0jDsNegZ46CUSePRIj5-Bw_0_UYc41b";
      };
    };
    environmentFile = "/etc/plan-ai-chat.env";
  };

#  security.acme.distributor-server = "https://acme.plan.ai";
  security.acme.distributor-server = "http://localhost:3444";

  users.users.deploy = {
    isSystemUser = true;
    group = "deploy";
    # so the user can login
    shell = "/run/current-system/sw/bin/bash";

    openssh.authorizedKeys.keys = [
      ''command="${pkgs.rrsync}/bin/rrsync /srv/update/",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIButBNqqpRpO+gMixN5J0HsLNEq26YIhXLC8wNHATs5W plan-ai-update''
    ];
  };
  users.groups.deploy = {};

  networking.hostName = "logos";
}
