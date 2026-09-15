{
  mkDataSet = mountpoint: quota: snapshot: options: mountOptions: {
    type = "zfs_fs";
    inherit mountpoint;
    mountOptions = ["defaults"] ++ mountOptions;
    options = {
      "com.sun:auto-snapshot" = toString snapshot;
    } // (if (quota != null) then {
      inherit quota;
      "reservation" = quota;
    } else { }
    ) // options;
  };

  rootFsOptions = {
    mountpoint = "none";
    # Performance
    compression = "zstd";
    dnodesize = "auto";
    normalization = "formD";
    atime = "off";
    xattr = "sa";
    # Snapshots
    "com.sun:auto-snapshot" = "false";
  };

  encryptedOpts = {
    canmount = "noauto";
    encryption = "aes-256-gcm";
    keylocation = "prompt";
    keyformat = "passphrase"; # secrets/encryption/zfs-secret
  };
}
