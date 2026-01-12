{ config, lib, pkgs, ... }:

{
  imports = [
    ../families/sdm845-mainline
  ];

  mobile.device.name = "google-blueline";
  mobile.device.identity = {
    name = "Pixel 3";
    manufacturer = "Google";
  };

  mobile.device.supportLevel = "supported";

  mobile.hardware = {
    ram = 1024 * 4;
    screen = {
      width = 1080; height = 2160;
    };
  };

#  mobile.boot.stage-1.shell.enable = true;
#
#  mobile.boot.stage-1.shell.shellOnFail = true;
#
#  mobile.boot.stage-1.shell.console = "ttyMSM0";

  boot.kernelParams = [
    "console=ttyMSM0,115200"  # Serial console for debugging
  ];
  #  "boot.shell_on_fail"      # Drop to shell on boot failure

  mobile.device.firmware = pkgs.callPackage ./firmware {};

  mobile.system.android.device_name = "Pixel 3";

  # Enable sparse rootfs for Android flashing
  mobile.rootfs.sparse = true;
}
