{ mobile-nixos,
  fetchFromGitHub,
  fetchpatch,
  stdenv,
  bc,
  bison,
  flex,
  gnumake,
  gcc,
  perl,
  python3,
  lib,
  features ? [],
  ...
}:

let
  version = "6.18.8";
  kernelSrc = fetchFromGitHub {
    owner = "sc7280-mainline";
    repo = "linux";
    rev = "v${version}-sc7280";
    hash = "sha256-na+vg4v6jI3rtiPBnbCUDDlULDvNpDAyfyH9jAOLbdc=";
  };

  configfile = stdenv.mkDerivation {
    name = "sc7280-kernel-config";
    src = kernelSrc;

    nativeBuildInputs = [
      gnumake
      gcc
      bc
      bison
      flex
      perl
      python3
    ];

    buildPhase = ''
      export ARCH=arm64
      export KCONFIG_CONFIG=$PWD/.config

      # Start with defconfig
      make defconfig

      # Add FP5 and essential NixOS options
      ./scripts/kconfig/merge_config.sh -m .config \
        arch/arm64/configs/fp5_defconfig \
        ${./defconfig}

      # Run olddefconfig to resolve dependencies
      make olddefconfig

      cp .config config
    '';

    installPhase = ''
      cp config $out
    '';
  };
in

mobile-nixos.kernel-builder {
  version = "6.18.8";
  configfile = configfile;
  src = kernelSrc;

  patches = [
    ./patches/fairphone.patch
  ];

  nativeBuildInputs = [ python3 ];

  makeFlags = [ "dtbs" ];

  # Don't use zinstall, it expects EFI boot files which ARM64 doesn't generate
  installTargets = [ ];

  postInstall = ''
    echo ":: Installing Image.gz kernel"
    cp -v "$buildRoot/arch/arm64/boot/Image.gz" "$out/Image.gz"
  '';

  isModular = true;
  isCompressed = "gz";
}
