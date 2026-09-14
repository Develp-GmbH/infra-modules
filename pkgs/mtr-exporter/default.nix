{pkgs, ...}:
pkgs.mtr-exporter.overrideAttrs (_: {
  version = "0.5.1";
  vendorHash = null;
  src = pkgs.fetchFromGitHub {
    owner = "mgumz";
    repo = "mtr-exporter";
    rev = "d49969f6ab7d586e966204e7e56a717f0d07b7fb";
    hash = "sha256-+myQg27TGclU+SfU8oO+DvXYqc/8sWE2zRK6fL2DhwM=";
  };
})
