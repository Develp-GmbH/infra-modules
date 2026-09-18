{ pkgs, writeShellApplication, symlinkJoin, ... }:

let
  systems-diff-machine = writeShellApplication {
    name = "systems-diff-machine";
    text = builtins.readFile ./machine.sh;
    runtimeInputs = [ pkgs.git ];
  };

  systems-diff-summary = writeShellApplication {
    name = "systems-diff-summary";
    runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.requests ])) ];
    text = ''
      exec python ${./summary.py} "$@"
    '';
  };
in symlinkJoin {
  name = "systems-diff";
  paths = [
    systems-diff-machine
    systems-diff-summary
  ];
  postBuild = ''
    $out/bin/systems-diff-summary --help
  '';
}
