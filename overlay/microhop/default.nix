{ lib
, pkgs
, ...
}:

let
  pkgsStatic = pkgs.pkgsStatic;
  version = "0.1.0";

  # Internal microhop binary package
  microhopBinary = pkgsStatic.rustPlatform.buildRustPackage rec {
    pname = "microhop";
    inherit version;

    src = pkgs.fetchFromGitHub {
      owner = "phodina";
      repo = "microhop";
      rev = "33246f832b2bc214b3b0de747bd0c61fe60cecc0";
      hash = "sha256-OMCe5Totz9kceAeghpJKHTLELWO2Eat1OqfVa9NeI5k=";
    };

    cargoLock = {
      lockFile = "${src}/Cargo.lock";
      outputHashes = {
        "kmoddep-0.1.5" = "sha256-8Q2cL2YYpItJ/aIwiqhT3iAsMwzBemAem0deKHRxXDs=";
      };
    };

    nativeBuildInputs = [
      pkgsStatic.pkg-config
      pkgsStatic.rustPlatform.bindgenHook
    ];

    buildInputs = [
      pkgsStatic.util-linuxMinimal.dev
    ];

    buildType = "release";

    cargoBuildFlags = [ "-p" "microhop" "--features" "nixos" ];

    doCheck = false;

    stripAllList = [ "bin" ];

    meta = with lib; {
      description = "Minimal initramfs /init binary";
      homepage = "https://github.com/phodina/microhop";
      license = licenses.asl20;
      maintainers = [];
      platforms = [ "aarch64-linux" "x86_64-linux" ];
    };
  };

in
# Main microgen package
pkgsStatic.rustPlatform.buildRustPackage rec {
  pname = "microgen";
  inherit version;

  src = pkgs.fetchFromGitHub {
    owner = "phodina";
    repo = "microhop";
    rev = "33246f832b2bc214b3b0de747bd0c61fe60cecc0";
    hash = "sha256-OMCe5Totz9kceAeghpJKHTLELWO2Eat1OqfVa9NeI5k=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    outputHashes = {
      "kmoddep-0.1.5" = "sha256-8Q2cL2YYpItJ/aIwiqhT3iAsMwzBemAem0deKHRxXDs=";
    };
  };

  nativeBuildInputs = [
    pkgsStatic.pkg-config
    pkgsStatic.rustPlatform.bindgenHook
    microhopBinary
    pkgsStatic.e2fsprogs
  ];

  buildInputs = [
    pkgsStatic.util-linuxMinimal
  ];

  buildType = "release";

  cargoBuildFlags = [ "-p" "microgen" "--features" "nixos" ];

  GIT_COMMIT = src.rev or "unknown";

  # Set environment variables to point to microhop and e2fsck binaries for include_bytes!()
  MICROHOP_BINARY_PATH = "${microhopBinary}/bin/microhop";
  E2FSCK_BINARY_PATH = "${pkgsStatic.e2fsprogs}/bin/e2fsck";

  doCheck = false;

  passthru = {
    microhop = microhopBinary;
  };

  meta = with lib; {
    description = "Initramfs generator tool for microhop";
    homepage = "https://github.com/phodina/microhop";
    license = licenses.asl20;
    maintainers = [];
    platforms = [ "aarch64-linux" "x86_64-linux" ];
  };
}
