{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    inputs.common.nixosModules.hcloud_base
    ./nginx.nix
    ./images.nix
  ];

  # replace this address with the one assigned to the instance
  mgit.hcloud.auto-network = "2a01:4f8:0000:0000::2/64";

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "cloud-images";

  security.acme.acceptTerms = true;
}
