{ stdenv, pkgs, lib, ... }:

pkgs.replaceVarsWith {
  name = "secrets";
  dir = "bin";
  src = ./secrets.sh;
  isExecutable = true;
  meta.mainProgram = "secrets";

  replacements = {
    inherit (stdenv) shell;
    binPath = lib.makeBinPath (with pkgs; [
      coreutils util-linux gnused ragenix
    ]);
  };
}
