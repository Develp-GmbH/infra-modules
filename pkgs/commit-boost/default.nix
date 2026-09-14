{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  protobuf,
  stdenv,
  writeShellScriptBin,
}:

rustPlatform.buildRustPackage rec {
  pname = "commit-boost-client";
  version = "0.9.6";

  src = fetchFromGitHub {
    owner = "Commit-Boost";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-+21dKCqDZpYMQR+tiWwcr88Akt3sv/2QspSGtbdpL4A=";
    fetchSubmodules = true;
  };

  cargoHash = "sha256-8gPrHSz8zwyDbX1MSdCx3/DzVCPLiWcQcwLpGeDpUO0=";

  nativeBuildInputs = let
    # crates/common/build.rs is executing a git command to print version
    fakeGit = writeShellScriptBin "git" "echo ${version}";
  in [
    pkg-config
    protobuf
    fakeGit
  ];

  buildInputs = [
    openssl
    protobuf
  ];

  doCheck = false;

  OPENSSL_NO_VENDOR = 1;

  meta = with lib; {
    description = "Modular sidecar for Ethereum validators to opt-in to commitment protocols";
    homepage = "https://github.com/Commit-Boost/commit-boost-client";
    changelog = "https://github.com/Commit-Boost/commit-boost-client/releases/tag/v${version}";
    license = with licenses; [ mit asl20 ];
    maintainers = [ ];
    mainProgram = "commit-boost-cli";
    platforms = platforms.unix;
  };
}
