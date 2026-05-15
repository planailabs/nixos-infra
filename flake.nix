{
  description = "plan ai infra";

  inputs = {
    nixpkgs.url = "https://git.plan.ai/plan-ai/nixpkgs/-/jobs/artifacts/plan-ai/raw/nixpkgs.tar.xz?job=build_x86_64-linux";
    hardware.url = "github:nixos/nixos-hardware";
    mkg-mod.url = "github:mkg20001/mkg-mod/master";
    mkg-mod.inputs.nixpkgs.follows = "nixpkgs";
    xnix.url = "git+https://git.xeredo.it/xeredo/xnix.git";
    xnix.inputs.nixpkgs.follows = "nixpkgs";
    acme-distributor.url = "github:mkg20001/acme-distributor";
    acme-distributor.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    xzar.url = "github:mkg20001/xzar";
    xzar.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    mac-mgmt.url = "git+ssh://git@git.plan.ai/plan-ai/mac-mgmt";
    mac-mgmt.inputs.nixpkgs.follows = "nixpkgs";
    mac-mgmt.inputs.rust-overlay.follows = "rust-overlay";
    plan-ai-chat.url = "git+ssh://git@git.plan.ai/plan-ai/chat";
    plan-ai-chat.inputs.nixpkgs.follows = "nixpkgs";
    supabase-self-service-consent.url = "git+ssh://git@git.plan.ai/plan-ai/supabase-self-service-consent";
    supabase-self-service-consent.inputs.nixpkgs.follows = "nixpkgs";
    common.url = "github:mgit-at/nixos-common";
    common.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    gitlab-incus-image.url = "git+https://git.mkg20001.io/mkg20001/gitlab-incus-image.git";
    gitlab-nix-ci.url = "git+https://git.mkg20001.io/mkg20001/gitlab-nix-ci.git";
    gitlab-nix-ci.inputs.nixpkgs.follows = "nixpkgs";
    gitlab-nix-ci.inputs.gitlab-incus-image.follows = "gitlab-incus-image";
 };

  outputs = {
    self,
    nixpkgs,
    mkg-mod,
    xnix,
    acme-distributor,
    disko,
    xzar,
    rust-overlay,
    mac-mgmt,
    plan-ai-chat,
    supabase-self-service-consent,
    common,
    home-manager,
    flake-utils,
    ...
  } @ inputs: let
    inherit (self) outputs;
  in {
    private = import ./private.nix;

    overlays.default = import ./pkgs/overlay.nix;
  } // flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ (import ./pkgs/overlay.nix) ];
      config.allowUnfree = true;
    };
  in {
    packages = {
      inherit (pkgs) cozempic obsidian-mcp-server obsidian-local-rest-api-plugin;
    } // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") inputs.gitlab-nix-ci.packages.x86_64-linux;
  }) // {

    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    nixosConfigurations = {
      plan-ai-pi = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        # > Our main nixos configuration file <
        modules = [
          mkg-mod.nixosModules.yggdrasil
          ./pi
          /* "${xnix}/defaults/hosted/base-backup.nix"
          "${xnix}/modules/admin/backup.nix" */
          /*{ nixpkgs.overlays = [
            (import ./pkgs/overlay.nix)
          ]; }*/
        ];
      };

      omen = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        # > Our main nixos configuration file <
        modules = [
          disko.nixosModules.disko
          mkg-mod.nixosModules.yggdrasil
          acme-distributor.nixosModules.acme-shim
          mac-mgmt.nixosModules.daemon
          mac-mgmt.nixosModules.nix-driver-sync
          ./omen
          { nixpkgs.overlays = [
            (import ./pkgs/overlay.nix)
            mac-mgmt.overlays.default
          ]; }
        ];
      };

      atlas = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        # > Our main nixos configuration file <
        modules = [
          disko.nixosModules.disko
          mkg-mod.nixosModules.yggdrasil
          acme-distributor.nixosModules.acme-shim
          ./atlas
          { nixpkgs.overlays = [
            (import ./pkgs/overlay.nix)
          ]; }
        ];
      };

      hyperion = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        # > Our main nixos configuration file <
        modules = [
          disko.nixosModules.disko
          mkg-mod.nixosModules.yggdrasil
          acme-distributor.nixosModules.acme-shim
          inputs.gitlab-nix-ci.nixosModules.gitlab-nix-ci
          ./hyperion
          { nixpkgs.overlays = [
            inputs.gitlab-incus-image.overlay
            inputs.gitlab-nix-ci.overlays.default
            (import ./pkgs/overlay.nix)
          ]; }
        ];
      };

      chronos = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        # > Our main nixos configuration file <
        modules = [
          mkg-mod.nixosModules.yggdrasil
          acme-distributor.nixosModules.acme-shim
          ./chronos
          { nixpkgs.overlays = [
            rust-overlay.overlays.default
            acme-distributor.overlays.default
            (import ./pkgs/overlay.nix)
          ]; }
        ];
      };

      deploy = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        # > Our main nixos configuration file <
        modules = [
          mkg-mod.nixosModules.yggdrasil
          ./deploy
          { nixpkgs.overlays = [
            (import ./pkgs/overlay.nix)
          ]; }
        ];
      };

      aarch64-builder = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          mkg-mod.nixosModules.yggdrasil
          ./aarch64-builder
          { nixpkgs.overlays = [
            (import ./pkgs/overlay.nix)
          ]; }
        ];
      };

      logos = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        # > Our main nixos configuration file <
        modules = [
          mkg-mod.nixosModules.yggdrasil
          acme-distributor.nixosModules.acme-shim
          acme-distributor.nixosModules.acme-distributor
          xzar.nixosModules.xzar
          mac-mgmt.nixosModules.default
          mac-mgmt.nixosModules.relay
          mac-mgmt.nixosModules.runner
          plan-ai-chat.nixosModules.default
          supabase-self-service-consent.nixosModules.default
          ./logos
          { nixpkgs.overlays = [
            rust-overlay.overlays.default
            xzar.overlays.default
            acme-distributor.overlays.default
            plan-ai-chat.overlays.default
            mac-mgmt.overlays.default
            (import ./pkgs/overlay.nix)
          ]; }
        ];
      };

      peira = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        # > Our main nixos configuration file <
        modules = [
          mkg-mod.nixosModules.yggdrasil
          acme-distributor.nixosModules.acme-shim
          xzar.nixosModules.xzar
          mac-mgmt.nixosModules.default
          mac-mgmt.nixosModules.relay
          ./peira
          { nixpkgs.overlays = [
            rust-overlay.overlays.default
            xzar.overlays.default
            acme-distributor.overlays.default
            mac-mgmt.overlays.default
            (import ./pkgs/overlay.nix)
          ]; }
        ];
      };

      agency = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          mkg-mod.nixosModules.yggdrasil
          acme-distributor.nixosModules.acme-shim
          mac-mgmt.nixosModules.web-agency
          ./agency
          { nixpkgs.overlays = [
            rust-overlay.overlays.default
            acme-distributor.overlays.default
            mac-mgmt.overlays.default
            (import ./pkgs/overlay.nix)
          ]; }
        ];
      };

      metis = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        # > Our main nixos configuration file <
        modules = [
          mkg-mod.nixosModules.yggdrasil
          acme-distributor.nixosModules.acme-shim
          xzar.nixosModules.xzar
          mac-mgmt.nixosModules.default
          ./metis
          { nixpkgs.overlays = [
            rust-overlay.overlays.default
            xzar.overlays.default
            acme-distributor.overlays.default
            mac-mgmt.overlays.default
            (import ./pkgs/overlay.nix)
          ]; }
        ];
      };

      obsidian = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          mkg-mod.nixosModules.yggdrasil
          acme-distributor.nixosModules.acme-shim
          home-manager.nixosModules.home-manager
          ./obsidian
          { nixpkgs.overlays = [
            acme-distributor.overlays.default
            (import ./pkgs/overlay.nix)
          ]; }
        ];
      };
    };
  };
}
