{ config, lib, pkgs, ... }:

{
  imports = [
    ./sound.nix
  ];

  mobile.hardware = {
    soc = "qualcomm-sdm845";
  };

  mobile.boot.stage-1 = {
    compression = "xz";
    kernel = {
      package = (pkgs.callPackage ./kernel { });
      modular = true;
    };
  };

  hardware.enableRedistributableFirmware = true;

  # Note: on devices it's highly likely no firmware is required during stage-1.
  # DRM *should* work fine without firmware.
  # Modems and such will pick them back up in stage-2.
  # Even though, we're eagerly adding firmware files that fit.
  # This is a workaround for non-modular kernels wanting to load the adsp firmware during stage-1.
  mobile.boot.stage-1.firmware = [
    (pkgs.runCommand "initrd-firmware" {} ''
      mkdir $out
      chmod -R +w $out

      # Copy extra a630 firmware from linux-firmware
      mkdir -p $out/lib/firmware/qcom
      cp -vf ${pkgs.linux-firmware}/lib/firmware/qcom/a630_sqe.fw $out/lib/firmware/qcom
      cp -vf ${pkgs.linux-firmware}/lib/firmware/qcom/a630_gmu.bin $out/lib/firmware/qcom

      # Copy ZAP shader firmware (a630_zap.mbn) from device-specific firmware
      # Path: qcom/sdm845/<Vendor>/<device>/a630_zap.mbn
      if [ -d "${config.mobile.device.firmware}/lib/firmware/qcom" ]; then
        cd ${config.mobile.device.firmware}/lib/firmware
        find qcom -name "a630_zap.mbn" | while read -r file; do
          mkdir -p "$out/lib/firmware/$(dirname "$file")"
          cp -v "$file" "$out/lib/firmware/$file"
        done || true
      else
        find  ${config.mobile.device.firmware} -iname "a630_zap.mbn"
        echo "Nope"
        exit 1
      fi
    '')
  ];


  mobile.system.type = "android";
  mobile.system.android = {
    # Assumed all SDM845 devices use A/B
    ab_partitions = lib.mkDefault true;
    # Assumed all SDM845 devices can boot with the same options.
    bootimg.flash = {
      offset_base = "0x00000000";
      offset_kernel = "0x00008000";
      offset_ramdisk = "0x01000000";
      offset_second = "0x00000000";
      offset_tags = "0x00000100";
      pagesize = "4096";
    };
    appendDTB = lib.mkDefault [
      "dtbs/qcom/sdm845-${config.mobile.device.name}.dtb"
    ];
  };

  mobile.usb.mode = "gadgetfs";
  # The identifiers used here serve as a compatible well-known identifier.
  mobile.usb.idVendor = lib.mkDefault "18D1"; # Google
  mobile.usb.idProduct = lib.mkDefault "D001"; # "Nexus 4"

  mobile.usb.gadgetfs.functions = {
    adb = "ffs.adb";
    mass_storage = "mass_storage.0";
    rndis = "rndis.usb0";
  };

  mobile.quirks.qualcomm.sdm845-modem.enable = true;

  # Enable sparse rootfs for Android flashing
  mobile.rootfs.sparse = true;
  mobile.rootfs.shrinkImage = true;
  mobile.rootfs.useStandardMkfs = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT}=="1", SUBSYSTEMS=="input", ATTRS{name}=="pmi8998_haptics", TAG+="uaccess", ENV{FEEDBACKD_TYPE}="vibra"
  '';
}
