{
  disko.devices = {
    disk = {
      osdisk = {
        type = "disk";
        device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_osdisk";
        content = {
          type = "gpt";
          partitions = {
            # BIOS boot partition — the VM boots legacy MBR/BIOS, so GRUB
            # needs this to embed itself on a GPT disk.
            boot = {
              size = "1M";
              type = "EF02";
            };
            ESP = {
              size = "2000M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            swap = {
              size = "2G";
              content = {
                type = "swap";
                discardPolicy = "both";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
