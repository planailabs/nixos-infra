{
  disko.devices = {
    disk = {
      nvme_a = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-SAMSUNG_MZVL2512HCJQ-00B00_S675NF0R800054_1";
        content = {
          type = "gpt";
          partitions = {
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
              priority = 2;
              size = "32G";
              content = {
                type = "swap";
                discardPolicy = "both";
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rtorrent";
              };
            };
          };
        };
      };

      nvme_b = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-SAMSUNG_MZVL2512HCJQ-00B00_S675NF0R800058_1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "2000M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                # mountpoint = "/boot";
              };
            };
            swap = {
              priority = 2;
              size = "32G";
              content = {
                type = "swap";
                discardPolicy = "both";
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rtorrent";
              };
            };
          };
        };
      };
    };
    zpool = {
      rtorrent = {
        type = "zpool";
        options = {
          autotrim = "on";
          cachefile = "none";
          # defaults
          autoexpand = "on";
        };
        rootFsOptions = {
          normalization = "formC";
          canmount = "off";
        # defaults
          acltype = "posixacl";
        # mountpoint = "legacy";
          xattr = "sa";
          utf8only = "on";
        };

        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
            # postCreateHook = "zfs snapshot rtorrent/root@blank";
          };
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options.mountpoint = "legacy";
          };
          home = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/home";
           # postCreateHook = "zfs snapshot rtorrent/home@blank";
          };
          incus = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
          };
        };
      };
    };
  };
}

