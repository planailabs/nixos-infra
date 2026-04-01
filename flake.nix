{
  description = "plan ai infra";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
    ...
  } @ inputs: let
    inherit (self) outputs;
  in {
    private = import ./private.nix;

    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    nixosConfigurations = {
      /* home-pi = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        # > Our main nixos configuration file <
        modules = [
          mkg-mod.nixosModules.yggdrasil
          ./pi
          "${xnix}/defaults/hosted/base-backup.nix"
          "${xnix}/modules/admin/backup.nix"
          { nixpkgs.overlays = [
            copyparty.overlays.default
            (import ./pkgs/overlay.nix)
          ]; }
        ];
      }; */

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

      logos = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        # > Our main nixos configuration file <
        modules = [
          mkg-mod.nixosModules.yggdrasil
          acme-distributor.nixosModules.acme-shim
          acme-distributor.nixosModules.acme-distributor
          xzar.nixosModules.xzar
          mac-mgmt.nixosModules.default
          plan-ai-chat.nixosModules.default
          ./logos
          { nixpkgs.overlays = [
            rust-overlay.overlays.default
            xzar.overlays.default
            acme-distributor.overlays.default
            plan-ai-chat.overlays.default
            (final: prev: {
              mac-mgmt-server = mac-mgmt.packages.${final.system}.server;
            })
            (import ./pkgs/overlay.nix)
          ]; }
        ];
      };
    };
  };
}
