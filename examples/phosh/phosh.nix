#
# This file represents safe opinionated defaults for a basic Phosh system.
#
# NOTE: this file and any it imports **have** to be safe to import from
#       an end-user's config.
#
{ config, lib, pkgs, options, ... }:

{
  mobile.beautification = {
    silentBoot = lib.mkDefault true;
    splash = lib.mkDefault true;
  };

  services.xserver.desktopManager.phosh = {
    enable = true;
    group = "users";
  };

  programs.calls.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    # Disabled since it uses `olm` which was marked insecure.
    #chatty              # IM and SMS
    # epiphany            # Web browser
    gnome-console       # Terminal
    # libcamera         # Camera support (disabled to reduce size)
    # megapixels        # Camera
  ];

  hardware.sensor.iio.enable = lib.mkDefault true;

  # Size optimization options
  documentation = {
    enable = lib.mkDefault false;
    doc.enable = lib.mkDefault false;
    man.enable = lib.mkDefault false;
    nixos.enable = lib.mkDefault false;
    info.enable = lib.mkDefault false;
  };

  # Reduce closure size
  environment.noXlibs = lib.mkDefault false; # Can't disable X libs for Phosh

  # Minimize locales - keep only English
  i18n.supportedLocales = lib.mkDefault [ "en_US.UTF-8/UTF-8" ];

  # Disable unnecessary firmware
  hardware.enableAllFirmware = lib.mkDefault false;

  assertions = [
    { assertion = options.services.xserver.desktopManager.phosh.user.isDefined;
    message = ''
      `services.xserver.desktopManager.phosh.user` not set.
        When importing the phosh configuration in your system, you need to set `services.xserver.desktopManager.phosh.user` to the username of the session user.
    '';
    }
  ];
}
