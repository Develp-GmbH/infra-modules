{
  lib,
  devices ? {},    # { sda = "/dev/disks/..."; sdb = "/dev/disks/..."; }
  secrets ? false, # Only relevant for hosts with VCs.
  mode ? "",       # Only relevant on bare metal hosts.
}:

assert builtins.isAttrs devices || abort "devices arg needs to be an object!";
assert devices != {}   || abort "devices need to be provided!";
assert builtins.elem mode ["" "mirror" "raidz1"] || abort "mode must be one of: '' (stripe), 'mirror', 'raidz1'";

let
  gpt = import ./gpt.nix;
  zfs = import ./zfs.nix;

  inherit (zfs) encryptedOpts;
in {
  devices = let
    mkGptLayout = index: name: {
      inherit name;
      value = {
        device = devices.${name};
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            # FIXME: Grub required for VPS legacy boot without UEFI.
            #                  Prio  Size   Name    Mount
            grub = gpt.mkGrub  0     "1M"   "GRUB";
            efi  = gpt.mkEFI   1     "2G"   "EFI"   "/boot${if index == 0 then "" else toString (index + 1)}";
            swap = gpt.mkSwap  2     "8G"   "SWAP";
            zfs  = gpt.mkZpool 3     "100%" "ZFS";
          };
        };
      };
    };
  in {
    # Provide index via imap0 for multiple /boot partitions.
    disk = lib.listToAttrs (lib.imap0 mkGptLayout (lib.attrNames devices));

    zpool = {
      rpool = {
        type = "zpool";
        inherit mode;
        inherit (zfs) rootFsOptions;
        datasets = {
          # Name                                           Mountpoint                                  Quota Snap  Options       Mount Opts
          "root"                           = zfs.mkDataSet "/"                                         "10G" true  {}            [];
          "nix"                            = zfs.mkDataSet "/nix"                                      "30G" false {}            [];
          "var"                            = zfs.mkDataSet "/var"                                      "10G" false {}            [];
          "private"                        = zfs.mkDataSet "/var/lib/private"                          null  false {}            [];
        } // lib.optionalAttrs secrets {
          "secret"                         = zfs.mkDataSet null                                        "10G" false encryptedOpts ["noauto"];
          "secret/web3signer"              = zfs.mkDataSet "/var/lib/private/web3signer"               "1G"  true  {}            ["noauto"];
          "secret/charon"                  = zfs.mkDataSet "/var/lib/private/charon"                   "1G"  true  {}            ["noauto"];
          "secret/nimbus-validator-client" = zfs.mkDataSet "/var/lib/private/nimbus-validator-client"  "1G"  true  {}            ["noauto"];
        };
      };
    };
  };
}