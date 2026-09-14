{
  buildGoModule,
  fetchFromGitHub,
  lib,
  nix-update-script,
}:

buildGoModule rec {
  pname = "geth";
  version = "1.17.4";

  src = fetchFromGitHub {
    owner = "ethereum";
    repo = "go-ethereum";
    rev = "v${version}";
    hash = "sha256-jgBKoSt3cdw3NyTi8SLBf28tvJIBAitkQNMlzfnIONE=";
  };

  proxyVendor = true;
  vendorHash = "sha256-18rqbSx3JGaQz3Fw38JShRikkTT4Gn+uqqbNZiJQaS8=";

  ldflags = ["-s" "-w"];

  doCheck = false;

  subPackages = [ "cmd/geth" ];

  passthru.updateScript = nix-update-script {};

  meta = with lib; {
    description = "Official golang implementation of the Ethereum protocol";
    homepage = "https://geth.ethereum.org/";
    license = with licenses; [lgpl3Plus gpl3Plus];
    mainProgram = "geth";
    platforms = ["x86_64-linux" "aarch64-linux"];
  };
}
