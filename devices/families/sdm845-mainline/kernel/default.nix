{ mobile-nixos
, fetchFromGitLab
, fetchpatch
, stdenv
, buildPackages
, ...
}:

let
  kernelSrc = fetchFromGitLab {
    owner = "sdm845";
    repo = "sdm845-next";
    rev = "6cead4b930f81753ed4122ce62b41abfebe178e1";
    hash = "sha256-9wbh+skNPMbCBUrJwccb8J2T8RrAJ8RWmozQM4fGOj4=";
  };

  configfile = stdenv.mkDerivation {
    name = "sdm845-kernel-config";
    src = kernelSrc;

    nativeBuildInputs = [
      buildPackages.gnumake
      buildPackages.gcc
      buildPackages.bc
      buildPackages.bison
      buildPackages.flex
      buildPackages.perl
      buildPackages.python3
    ];

    buildPhase = ''
      export ARCH=arm64
      export KCONFIG_CONFIG=$PWD/.config

      # Start with defconfig
      make defconfig

      # Merge sdm845.config fragment if it exists
      if [ -f arch/arm64/configs/sdm845.config ]; then
        scripts/kconfig/merge_config.sh -m .config arch/arm64/configs/sdm845.config
      fi

      # Add essential NixOS required kernel options
      cat >> .config <<EOF
# NixOS required options
CONFIG_DEVTMPFS=y
CONFIG_CGROUPS=y
CONFIG_INOTIFY_USER=y
CONFIG_SIGNALFD=y
CONFIG_TIMERFD=y
CONFIG_EPOLL=y
CONFIG_NET=y
CONFIG_SYSFS=y
CONFIG_PROC_FS=y
CONFIG_FHANDLE=y
CONFIG_CRYPTO_HMAC=y
CONFIG_CRYPTO_SHA256=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_TMPFS_XATTR=y
CONFIG_SECCOMP=y
CONFIG_TMPFS=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_BINFMT_ELF=y
CONFIG_UNIX=y
CONFIG_CC_CAN_LINK=y
EOF

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
  version = "6.19.0-rc4-next-20260109-sdm845";
  configfile = configfile;
  src = kernelSrc;

  patches = [];

  nativeBuildInputs = [ buildPackages.python3 ];

  # Don't use zinstall, it expects EFI boot files which ARM64 doesn't generate
  installTargets = [ ];

  postInstall = ''
    # Manually copy the kernel image
    echo ":: Installing Image.gz kernel"
    cp -v "$buildRoot/arch/arm64/boot/Image.gz" "$out/Image.gz"

    # Create symlink for compatibility
    ln -sv Image.gz "$out/vmlinuz" || true
  '';

  isModular = false;
  isCompressed = "gz";
}
