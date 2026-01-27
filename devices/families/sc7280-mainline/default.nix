{ config, lib, pkgs, ... }:

{
  imports = [
  ];

  mobile.device.dtbSocPrefix = lib.mkDefault "sc7280";

  mobile.hardware = {
    soc = "qualcomm-sc7280";
  };

  mobile.boot.stage-1 = {
    compression = "xz";
    kernel.package = (pkgs.callPackage ./kernel { });
  };

  hardware.enableRedistributableFirmware = true;

  # Note: on devices it's highly likely no firmware is required during stage-1.
  # DRM *should* work fine without firmware.
  # Modems and such will pick them back up in stage-2.
  mobile.boot.stage-1.firmware = [
    (pkgs.runCommand "initrd-firmware" {} ''
      cp -vrf ${config.mobile.device.firmware} $out
      chmod -R +w $out
      # Big file, fills and breaks stage-1
      find $out/lib/firmware/qcom/${config.mobile.device.dtbSocPrefix} -name "modem.mbn" -delete -print
    '')
  ];

  mobile.system.type = "android";
  mobile.system.android = {
    # Assumed all SC7280 devices use A/B
    ab_partitions = lib.mkDefault true;
    # Assumed all SC7280 devices can boot with the same options.
    bootimg.flash = {
      offset_base = "0x00000000";
      offset_kernel = "0x00008000";
      offset_ramdisk = "0x01000000";
      offset_second = "0x00000000";
      offset_tags = "0x00000100";
      pagesize = "4096";
    };
    appendDTB = lib.mkDefault [
      "dtbs/qcom/${config.mobile.device.dtbSocPrefix}-${config.mobile.device.name}.dtb"
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

  mobile.quirks.qualcomm.sc7280-modem.enable = lib.mkDefault true;

  services.udev.extraRules = ''
    SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT}=="1", SUBSYSTEMS=="input", ATTRS{name}=="*haptics", TAG+="uaccess", ENV{FEEDBACKD_TYPE}="vibra"
  '';
}
