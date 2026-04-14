{
  disko.devices = {
    disk = {
      ssd = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Samsung_SSD_850_PRO_512GB_S250NWAG831361V";
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
            zil = {
              size = "10G";
              content = {
                type = "zfs";
                pool = "omen-hdd";
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "omen";
              };
            };
          };
        };
      };

      hdd_a = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TOSHIBA_DT01ACA300_895D82NAS";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "2930265088K";
              content = {
                type = "zfs";
                pool = "omen-hdd";
              };
            };
            ext4 = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/hdd_leftover";
              };
            };
          };
        };
      };

      hdd_b = {
        type = "disk";
        device = "/dev/disk/by-id/ata-WDC_WD40EFAX-68JH4N1_WD-WX22D917F7AC";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "2930265088K";
              content = {
                type = "zfs";
                pool = "omen-hdd";
              };
            };
          };
        };
      };
    };
    zpool = {
      omen-hdd = {
        type = "zpool";
        mode = {
          topology = {
            type = "topology";
            vdev = [
              {
                mode = "mirror";
                members = [ "hdd_a" "hdd_b" ];
              }
            ];
            log = [
              {
                members = [ "/dev/disk/by-partlabel/disk-ssd-zil" ];
              }
            ];
          };
        };
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
      };

      omen = {
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

