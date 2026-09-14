{
  fetchzip,
  jre,
  lib,
  makeWrapper,
  nix-update-script,
  stdenv,
}:
stdenv.mkDerivation rec {
  pname = "web3signer";
  version = "26.4.2";

  src = fetchzip {
    url = "https://github.com/Consensys/${pname}/releases/download/${version}/${pname}-${version}.tar.gz";
    hash = "sha256-ESbdSCIRDWr13L07LQiuFbPVSSFpKwqmtHEuyMQDMBU=";
  };

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    mkdir -p $out
    cp -r bin lib migrations $out/
    wrapProgram $out/bin/${pname} --set JAVA_HOME "${jre}"
  '';

  doInstallCheck = true;
  # Migration schemas for the slashing protection DB
  installCheckPhase = ''
    test -e $out/migrations/postgresql/V00001__initial.sql
  '';

  passthru.updateScript = nix-update-script {};

  meta = with lib; {
    description = "Web3Signer is an open-source signing service capable of signing on multiple platforms (Ethereum1 and 2, Filecoin) using private keys stored in an external vault, or encrypted on a disk";
    homepage = "https://github.com/ConsenSys/web3signer";
    license = licenses.asl20;
    mainProgram = "web3signer";
    platforms = ["x86_64-linux"];
    sourceProvenance = with sourceTypes; [binaryBytecode];
  };
}
