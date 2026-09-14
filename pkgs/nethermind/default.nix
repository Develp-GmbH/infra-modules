{
  buildDotnetModule,
  dotnetCorePackages,
  fetchFromGitHub,
  lib,
  lz4,
  nix-update-script,
  rocksdb,
  snappy,
  stdenv,
  writeShellScriptBin,
  zstd,
}: let
  self = buildDotnetModule rec {
    pname = "nethermind";
    version = "1.39.1";

    src = fetchFromGitHub {
      owner = "NethermindEth";
      repo = pname;
      rev = version;
      hash = "sha256-KLKbDNHy40iXZHUO+RbwbCj4pN+vKrcpCCjMd7NCb9U=";
      fetchSubmodules = true;
    };

    buildInputs = [
      lz4
      snappy
      stdenv.cc.cc.lib
      zstd
    ];

    runtimeDeps = [
      rocksdb
      snappy
    ];

    projectFile = [
      "src/Nethermind/Nethermind.Runner/Nethermind.Runner.csproj"
    ];
    nugetDeps = ./nuget-deps.json;

    executables = [
      "nethermind"
    ];

    dotnet-sdk = dotnetCorePackages.sdk_10_0;
    dotnet-runtime = dotnetCorePackages.aspnetcore_10_0;

    passthru = {
      passthru.updateScript = nix-update-script {};

      # buildDotnetModule's `fetch-deps` uses `writeShellScript` instead of writeShellScriptBin making nix run .#nethermind.fetch-deps command to fail
      # This alias solves that issue. On parent folder, we only need to run this command to produce a new nuget-deps.nix file with updated deps:
      # $ nix run '.#nethermind.fetch-nethermind-deps' pkgs/nethermind/nuget-deps.json
      fetch-nethermind-deps = writeShellScriptBin "fetch-nethermind-deps" ''${self.fetch-deps} $@'';
    };

    meta = {
      description = "Our flagship Ethereum client for Linux, Windows, and macOS—full and actively developed";
      homepage = "https://nethermind.io/nethermind-client";
      license = lib.licenses.gpl3;
      mainProgram = "Nethermind.Runner";
      platforms = ["x86_64-linux"];
    };
  };
in
  self
