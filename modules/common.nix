{ inputs, config, pkgs, lib, ... }:

with lib;

{
  imports = [
    ./vm-fix.nix
  ];

  # hack: is broken
  # services.logrotate.checkConfig = false;

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # If you want to use overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;

      /* problems.matchers = [
        {
          kind = "maintainerless";
          handler = "warn";
        }
      ]; */
    };
  };

  users.users = {
    root = {
      openssh.authorizedKeys.keys = [
        # mkg
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIBBEhZ7sLQCNZXBunHMxEDS2Niy3wpnHgUPDBCNeKew maciej@mkg-razer"
        # sebfried
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDZOo2bcD9nCYzO1F8k4irkpfYxBtFkp+XzItrgQ9n6 gitlab"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0lbtC49VLxNoHbBOSxadGIfXsMinUyXuaIqgDfzFAT git.plan.ai"
        # alberto
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKJFHNMyr+Ny78rEkBJU13SczCGrNAZTH/QpOctaDinp alberto@plan.ai"
        # sysadmin bot
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICTSrNdtjar9uZ8BPHQ0DFU4GVfrvZQJnVduLgE0ATfT mac-mgmt@deploy"
        # loreno
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEnF5ZgwSXvWSz116RYt5otf2TNVeCKrBMn+/DtWbQKl loreno@plan.ai"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILHfeMXlLMTKKaOxFUiHOVPt2ouXeX92p6NeBk77HEQg"
      ];
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Vienna";

  # Configure keymap in X11
  services.xserver.xkb.layout = "de";

  # This setups a SSH server. Very important if you're setting up a headless system.
  # Feel free to remove if you don't need it.
  services.openssh = {
    enable = true;
    settings = {
      # Forbid root login through SSH.
      PermitRootLogin = mkForce "without-password";
      # Use keys only. Remove if you want to SSH using password (not recommended)
      PasswordAuthentication = mkForce false;
    };
  };

  # Disable sudo as we use root ssh authentication only
  security.sudo.enable = false;
  # Disable su going root
  # FIXME: breaks reloading user units for root
  # security.pam.services.su.rootOK = mkForce false;

  # This will add each flake input as a registry
  # To make nix3 commands consistent with your flake
  # nix.registry = (lib.mapAttrs (_: flake: {inherit flake;})) ((lib.filterAttrs (_: lib.isType "flake")) inputs);

  # This will additionally add your inputs to the system's legacy channels
  # Making legacy nix commands consistent as well, awesome!
  /* nix.nixPath = ["/etc/nix/path"];
  environment.etc =
    lib.mapAttrs'
    (name: value: {
      name = "nix/path/${name}";
      value.source = value.flake;
    })
    config.nix.registry; */

  nix.settings = {
    # Enable flakes and new 'nix' command
    experimental-features = "nix-command flakes";
    # Deduplicate and optimize nix store
    auto-optimise-store = true;
    # Binary caches
    substituters = [
      "https://cache.nixos.org/"
      "https://xzar.plan.ai/"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "xzar.plan.ai:KUE66pjr6UX5HHCn9kedN1DJ2J5nSlBrKmE7tUjXewE="
    ];
  };

  nix.channel.enable = false;

  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 14d";

  # testing future stuff
  networking.useNetworkd = true;
  boot.initrd.systemd.enable = true;
  networking.nftables.enable = true;

  programs.git.enable = true;

  environment.systemPackages = with pkgs; [
    dool
    tcpdump
    nload
    unzip
    wget
    nethogs
    iptraf-ng
    claude-code
    cozempic
    opencode
    neovim
    rsync
  ];

  programs.screen = {
    enable = true;
    screenrc = ''
      defscrollback 10000
      startup_message off
    '';
  };

  programs.htop = {
    enable = true;
    settings = {
      hide_userland_threads = true;
    };
  };

  programs.mtr.enable = true;

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
    openFirewall = false;
  };

  # Allow logos (over yggdrasil) to scrape metrics on ports 9000-9999
  networking.firewall.extraInputRules = ''
    ip6 saddr ${(import ./yggdrasil-ips.nix).logos} tcp dport 9000-9999 accept
  '';
}

