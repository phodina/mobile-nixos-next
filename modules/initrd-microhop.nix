{ config, pkgs, lib, ... }:

let
  inherit (lib)
    mkIf
    mkOption
    mkEnableOption
    types
  ;

  cfg = config.mobile.boot.stage-1.microhop;
  device = config.mobile.device;
  stage-1 = config.mobile.boot.stage-1;

  microhopConfig = pkgs.writeText "microhop-${device.name}.conf" ''
    # Microhop configuration for ${device.name}
    # Kernel modules to load
    modules:
${lib.concatMapStringsSep "\n" (mod: "  - ${mod}") cfg.modules}

    # Mount configuration
    disks:
${lib.concatStringsSep "\n" (map (disk: "  ${disk}") cfg.disks)}

    # Execute systemd/init after switching root
    init: ${cfg.init}

    # Temporary sysroot location
    sysroot: ${cfg.sysroot}

    # Log level: debug, info, quiet
    log: ${cfg.logLevel}
${lib.optionalString (cfg.overlayDevice != null) ''
    # Overlayfs configuration
    overlay_dev: ${cfg.overlayDevice}
''}
  '';

  initrd = pkgs.stdenv.mkDerivation {
    name = "initramfs-microhop-${device.name}";
    
    nativeBuildInputs = with pkgs; [
      config.mobile.boot.stage-1.microhop.microgen
      cpio
      gzip
      xz
    ];
    
    unpackPhase = "true";
    
    buildPhase = ''
      mkdir -p $TMPDIR/rootfs/lib/modules
      
      ${lib.optionalString (stage-1.kernel.package != null) ''
        if [ -d "${stage-1.kernel.package}/lib/modules" ] && [ "$(ls -A ${stage-1.kernel.package}/lib/modules 2>/dev/null)" ]; then
          echo "Copying kernel modules..."
          cp -r ${stage-1.kernel.package}/lib/modules/* $TMPDIR/rootfs/lib/modules/ || true
        fi
      ''}

      ${lib.optionalString (stage-1 ? firmware && stage-1.firmware != null) ''
        if [ -d "${stage-1.firmware}/lib/firmware" ] && [ "$(ls -A ${stage-1.firmware}/lib/firmware 2>/dev/null)" ]; then
          mkdir -p $TMPDIR/rootfs/lib/firmware
          echo "Copying firmware from ${stage-1.firmware}..."
          cp -rv ${stage-1.firmware}/lib/firmware/* $TMPDIR/rootfs/lib/firmware/ || true
        fi
      ''}

      ${lib.optionalString (cfg.firmwareFiles != []) ''
        mkdir -p $TMPDIR/rootfs/lib/firmware
        echo "Copying specific firmware files..."
        ${lib.concatMapStringsSep "\n" (fwFile: ''
          # Check if the firmware file exists
          if [ ! -f "${fwFile}" ]; then
            echo "ERROR: Required firmware file not found: ${fwFile}"
            exit 1
          fi
          
          FW_RELATIVE_PATH=$(echo "${fwFile}" | sed 's|.*/lib/firmware/||')
          FW_DEST_DIR=$(dirname "$TMPDIR/rootfs/lib/firmware/$FW_RELATIVE_PATH")
          
          mkdir -p "$FW_DEST_DIR"
          
          echo "  Copying: $FW_RELATIVE_PATH"
          cp -v "${fwFile}" "$TMPDIR/rootfs/lib/firmware/$FW_RELATIVE_PATH"
          
          if [ ! -f "$TMPDIR/rootfs/lib/firmware/$FW_RELATIVE_PATH" ]; then
            echo "ERROR: Failed to copy firmware file: ${fwFile}"
            exit 1
          fi
        '') cfg.firmwareFiles}
        echo "All firmware files copied successfully"
      ''}
      
      mkdir -p $out
      
      echo "Generating initramfs with microhop/microgen..."
      echo "Configuration: ${microhopConfig}"
      
      MICROGEN_CMD="${cfg.microgen}/bin/microgen new \
        --root $TMPDIR/rootfs \
        --config ${microhopConfig}"
      
      ${lib.optionalString (stage-1.kernel.package ? configfile && stage-1.kernel.package.configfile != null) ''
        MICROGEN_CMD="$MICROGEN_CMD --kernel-config ${stage-1.kernel.package.configfile}"
      ''}
      
      MICROGEN_CMD="$MICROGEN_CMD \
        --filesystems ${lib.concatStringsSep "," cfg.filesystems} \
        --block-devices ${lib.concatStringsSep "," cfg.blockDevices} \
        --output $TMPDIR/build \
        --file $out/initrd"
      
      echo "Running: $MICROGEN_CMD"
      eval "$MICROGEN_CMD"
    '';
    
    installPhase = true;
  };

in
{
  options.mobile.boot.stage-1.microhop = {
    enable = mkEnableOption "microhop initramfs" // {
      description = ''
        Use microhop Rust-based initramfs instead of the default Mobile NixOS Ruby-based init.
        
        Microhop provides a minimal, fast, single-binary init system suitable for
        embedded and mobile devices.
      '';
    };

    microgen = mkOption {
      type = types.package;
      description = ''
        The microgen package to use for generating the initramfs.
        This should come from the microhop flake input.
      '';
    };

    microhop = mkOption {
      type = types.package;
      description = ''
        The microhop binary package (the init binary).
        This should come from the microhop flake input.
      '';
    };

    modules = mkOption {
      type = types.listOf types.str;
      default = if (stage-1 ? kernel && stage-1.kernel ? modules && stage-1.kernel.modules != null)
                then stage-1.kernel.modules
                else [];
      description = ''
        List of kernel modules to load in initramfs.
        Defaults to the modules specified in stage-1.kernel.modules.
      '';
    };

    disks = mkOption {
      type = types.listOf types.str;
      default = [ "NIXOS_ROOT: ext4,,rw" ];
      description = ''
        Disk mount configuration in microhop format.
        Format: "LABEL: fstype,mountpoint,options"
        or "UUID: fstype,mountpoint,options"
        or "/dev/device: fstype,mountpoint,options"
      '';
      example = [
        "NIXOS_ROOT: ext4,/,rw"
        "/dev/mmcblk0p1: vfat,/boot,ro"
      ];
    };

    filesystems = mkOption {
      type = types.listOf types.str;
      default = [ "ext4" "f2fs" "vfat" ];
      description = ''
        List of filesystem types to support.
      '';
    };

    blockDevices = mkOption {
      type = types.listOf types.str;
      default = [ "sdhci" "ufshcd" ];
      description = ''
        List of block device drivers to support.
      '';
    };

    init = mkOption {
      type = types.str;
      default = "/sbin/init";
      description = ''
        Path to init binary to execute after switching root.
      '';
    };

    sysroot = mkOption {
      type = types.str;
      default = "/sysroot";
      description = ''
        Temporary sysroot mount point.
      '';
    };

    logLevel = mkOption {
      type = types.enum [ "debug" "info" "quiet" ];
      default = "info";
      description = ''
        Log level for microhop init.
      '';
    };

    overlayDevice = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Device to use for overlayfs upper/work directories.
        If null, no overlayfs is used.
      '';
      example = "/dev/mmcblk0p2";
    };

    firmwareFiles = mkOption {
      type = types.listOf types.path;
      default = [];
      description = ''
        List of specific firmware files to copy to the initramfs.
        Each file will be copied to /lib/firmware in the initramfs.
        The build will fail if any of the specified files is missing.
        
        Use this for device-specific firmware that must be present
        in the initramfs for the device to boot properly.
      '';
      example = lib.literalExpression ''
        [
          "''${pkgs.linux-firmware}/lib/firmware/qcom/sdm845/adsp.mdt"
          "''${device.firmware}/lib/firmware/a630_gmu.bin"
        ]
      '';
    };
  };

  config = mkIf cfg.enable {
    # Disable the default Mobile NixOS stage-1
    mobile.boot.stage-1.enable = false;
    
    # Disable NixOS default initrd
    boot.initrd.enable = false;

    # Override the initrd output
    mobile.outputs.initrd = "${initrd}/initrd";
    
    system.build.initialRamdisk = initrd;

    # We don't need most of the Mobile NixOS stage-1 infrastructure
    boot.supportedFilesystems = lib.mkOverride 10 [];
    boot.initrd.supportedFilesystems = lib.mkOverride 10 [];
  };
}
