{ config, lib, pkgs, ... }:

{
  imports = [
    ../families/sdm845-mainline
  ];

  mobile.device.name = "oneplus-enchilada";
  mobile.device.identity = {
    name = "OnePlus 6";
    manufacturer = "OnePlus";
  };
  mobile.device.supportLevel = "supported";

  mobile.hardware = {
    ram = 1024 * 8;
    screen = {
      width = 1080; height = 2280;
    };
  };

  mobile.device.firmware = pkgs.callPackage ./firmware {};

  mobile.system.android.device_name = "OnePlus6";

  # Kernel command line parameters
  boot.kernelParams = [
    "console=ttyMSM0,115200"  # Serial console for debugging
    "boot.shell_on_fail"      # Drop to shell on boot failure
  ];

  # Enable interactive shell in initrd for debugging
  mobile.boot.stage-1.shell = {
    enable = true;           # Drops to shell before switching to stage-2
    shellOnFail = true;      # Also drop to shell on any failure
    console = "ttyMSM0";     # Use serial console for shell
  };

  # Touchscreen support in initrd
  mobile.boot.stage-1.kernel.modules = [
    "i2c_qcom_geni"
    "rmi_core"
    "rmi_i2c"
  ];
}
