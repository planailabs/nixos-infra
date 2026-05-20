{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
  ];

  systemd.network = {
    networks."40-public0" = {
      matchConfig = {
        Name = "public0";
      };
      gateway = [ "65.108.140.193" ];
      addresses = [
        { addressConfig = { Address = "65.108.140.227/26"; Peer = "65.108.140.193"; }; }
      ];
    };
  };

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  mkg.mod = {
    yggdrasil = {
      enable = true;
      port = 14455;
      peers = [ "tcp://ygg.mkg20001.io:80" "tls://ygg.mkg20001.io:443" ];
    };
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.liveRestore = false;
  virtualisation.incus.enable = true;

  systemd.services.docker-iptables-fix = {
    path = with pkgs; [ iptables-nftables-compat ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for i in $(seq 1 100); do
        sleep 2s
        iptables -P FORWARD ACCEPT
        ip6tables -P FORWARD ACCEPT
      done
    '';
  };
  networking.hostName = "deploy";

  nix = {
    gc.automatic = mkForce false;

    settings = {
      # sandbox = true;
      trusted-users = [ "root" "@builder" ];
      # Keep the build dependencies of derivations arround.
      gc-keep-outputs = true;
      gc-keep-derivations = true;
      env-keep-derivations = true;
      # Automatic gc during build. Keep at least 12 gig free, gc if below 6 gig.
      min-free = toString (6 * 1024 * 1024 * 1024);
      max-free = toString (12 * 1024 * 1024 * 1024);
      extra-platforms = [ "aarch64-linux" "armv7l-linux" "armv6l-linux" "i686-linux" ];
    };

    buildMachines = [
      {
        hostName = "aarch64.plan.ai";
        systems = [ "aarch64-linux" "armv7l-linux" "armv6l-linux" ];
        maxJobs = 4;
        supportedFeatures = [ "nixos-test" "big-parallel" ];
      }
      {
        hostName = "neon.i.xeredo.it";
        systems = [ "x86_64-linux" "i686-linux" ];
        maxJobs = 8;
        supportedFeatures = [ "nixos-test" "big-parallel" ];
      }
    ];
    distributedBuilds = true;
  };

  programs.ssh.extraConfig = ''
    Host neon.i.xeredo.it
      Port 37017
      User maciej
  '';

  boot.binfmt.emulatedSystems = [ "aarch64-linux" "armv7l-linux" "armv6l-linux" ];

  environment.systemPackages = with pkgs; [
    github-cli
    nixpkgs-review
    python3
    jq
    openssl
    diffoscope
  ];

  programs.bash.interactiveShellInit = lib.mkAfter ''
    MID=$(cut -c1-5 /etc/machine-id 2>/dev/null || echo "?????")
    _mid_palette=(81 117 123 156 159 186 187 217 218 222 223 229)
    if [[ $MID =~ ^[0-9a-f]+$ ]]; then
      _mid_hash=$((16#$MID))
    else
      _mid_hash=0
    fi
    MID_COLOR=''${_mid_palette[$((_mid_hash % ''${#_mid_palette[@]}))]}
    [ -r /etc/friendly-name ] && FRIENDLY_NAME=$(cat /etc/friendly-name)
    HOST_LABEL="''${FRIENDLY_NAME:-\h-$MID}"
    PS1="\[\033[01;38;5;''${MID_COLOR}m\]($HOST_LABEL)\[\033[00m\] $PS1"
    PS1="\''${IN_NIX_SHELL:+\[\e[33m\](nix:\$IN_NIX_SHELL)\[\e[0m\] }$PS1"
    PS1="\n$PS1"
  '';

  environment.shellAliases = {
    yolo = "env IS_SANDBOX=1 claude --dangerously-skip-permissions";
  };

  services.mac-mgmt = {
    enable = true;
    serverUrl = "https://api.plan.ai";
    version = "0.1.5";
    environmentFile = "/etc/mac-mgmt.env";
    settings = {
      daemon.log_level = "info";
    };
    system = "x86_64-linux";
  };

  systemd.services.mac-mgmt.unitConfig.ConditionPathExists = "/etc/mac-mgmt.env";
}

