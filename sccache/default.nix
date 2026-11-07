# S3 (Garage) backend for sccache, data on the Hetzner Storage Box.
{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/sccache.nix"
    ./storagebox.nix
    ./garage.nix
    ./nginx.nix
  ];

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  security.acme.distributor-server = "https://acme.plan.ai";

  networking.hostName = "sccache";
}
