# Copyright (C) develp GmbH 2024 All Rights Reserved
{disks}: {
  devices = {
    disk = {
      sda = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 0;
              size = "4G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };

            zfs = {
              priority = 1;
              end = "-64G";
              type = "BF00";
              content = {
                type = "zfs";
                pool = "zfs_root";
              };
            };

            swap = {
              priority = 2;
              size = "64G";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };
          };
        };
      };
      sdb = {
        type = "disk";
        device = builtins.elemAt disks 1;
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zfs_root";
              };
            };
          };
        };
      };
    };
    zpool = {
      zfs_root = {
        type = "zpool";
        mode = "mirror";
        rootFsOptions = {
          compression = "zstd";
          "com.sun:auto-snapshot" = "false";
        };
        datasets = {
          "root" = {
            mountpoint = "/";
            type = "zfs_fs";
            options = {
              "com.sun:auto-snapshot" = "false";
              mountpoint = "legacy";
            };
          };
          "root/nix" = {
            mountpoint = "/nix";
            type = "zfs_fs";
            options = {
              "com.sun:auto-snapshot" = "false";
              canmount = "on";
              mountpoint = "legacy";
              refreservation = "100GiB";
            };
          };
          "root/var" = {
            mountpoint = "/var";
            type = "zfs_fs";
            options = {
              "com.sun:auto-snapshot" = "false";
              canmount = "on";
              mountpoint = "legacy";
            };
          };
          "root/var/lib" = {
            mountpoint = "/var/lib";
            type = "zfs_fs";
            options = {
              "com.sun:auto-snapshot" = "false";
              canmount = "on";
              mountpoint = "legacy";
            };
          };
          "root/var/lib/.develp" = {
            mountpoint = "/var/lib/.develp";
            mountOptions = ["noauto"];
            type = "zfs_fs";
            options = {
              "com.sun:auto-snapshot" = "false";
              mountpoint = "legacy";
              canmount = "noauto"; # WARNING: Enabling causes failure to boot.
              encryption = "aes-256-gcm";
              keylocation = "prompt";
              keyformat = "passphrase"; # secrets/encryption/zfs-secret
              quota = "50M";
              reservation = "50M";
            };
          };
        };
      };
    };
  };
}
