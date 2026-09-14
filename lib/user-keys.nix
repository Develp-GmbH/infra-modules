# Copyright (C) develp GmbH 2025 All Rights Reserved
{lib}: let
  # Use of no-touch-required keys causes 'age: error: unknown recipient type'.
  filterNoTouchKeys = keys: let
    isNotNoTouch = key: lib.hasPrefix "no-touch-required " key;
  in
    builtins.filter isNotNoTouch keys;

  # To get keys for a single user
  getUserKeys = userInfo: let
    sshKeys = userInfo.openssh.authorizedKeys.keys or [];
    agenixKeys = userInfo.agenixKeys or [];
  in
    (filterNoTouchKeys sshKeys) ++ agenixKeys;

  inherit (builtins) concatMap attrNames;
in
  # Return a single function that gets all user keys
  usersInfo: concatMap (user: getUserKeys (usersInfo.${user})) (attrNames usersInfo)
