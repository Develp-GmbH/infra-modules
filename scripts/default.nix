{ pkgs, ... }:

let
  stripFilename = removeSuffix ".sh" (
    builtins.baseNameOf (toString file)
  );

  mkScript = file: runtimeInputs: pkgs.writeShellApplication {
    name = stripFilename file;
    text = builtins.readFile file;
    inherit runtimeInputs;
  };

  bootstrap-machine     = mkScript ./bootstrap-machine.sh     [ pkgs.nixos-anywhere ];
  cachix-setup          = mkScript ./cachix-setup.sh          [ pkgs.cachix ];
  check-cachix-expiry   = mkScript ./check-cachix-expiry.sh   [ pkgs.curl ];
  compare-system-config = mkScript ./compare-system-config.sh [ pkgs.git ];

  system-diff-summary = pkgs.writeShellScriptBin "system-diff-summary" let
    python = pkgs.python3.withPackages (ps: [ ps.requests ]);
  in ''
    exec ${python}/bin/python ${./system-diff-summary.py} "$@"
  '';
in {
  inherit check-config start-dev;

  all = pkgs.symlinkJoin {
    name = "develp-infra-scripts";
    paths = [
      bootstrap-machine
      cachix-setup
      check-cachix-expiry
      check-validator-state
      compare-system-config
      generate-report
      system-diff-summary
    ];
  };
}
