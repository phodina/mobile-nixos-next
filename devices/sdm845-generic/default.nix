{ config, lib, pkgs, ... }:

{
  imports = [
    ../families/sdm845-mainline
  ];

  mobile.device.name = "sdm845-generic";
  mobile.device.identity = {
    name = "SDM845 Generic";
    manufacturer = "Generic";
  };
  mobile.device.supportLevel = "supported";

  # Values are determined in runtime
  mobile.hardware = {
    ram = 1024 * 4;
    screen = {
      width = 0; height = 0;
    };
  };

  mobile.system.android.u-boot = {
    enable = true;
    package = pkgs.tow-boot;
  };

  mobile.device.firmware = pkgs.callPackage ./firmware {};

  mobile.system.android.device_name = "sdm845-generic";
}
