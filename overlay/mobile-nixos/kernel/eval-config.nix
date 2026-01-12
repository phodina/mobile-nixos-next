# This file includes fragments of <nixpkgs/nixos/modules/system/boot/kernel_config.nix>
{ lib
, path
, modules ? []
, structuredConfig
, version
, writeShellScript
}: rec {
  module = import (path + "/nixos/modules/system/boot/kernel_config.nix");
  config = (lib.evalModules {
    modules = [
      module
      (
        #
        # This module adds kernel config file generation from the structured attributes.
        #
        { config, lib, ... }:

        let
          mkValue = with lib; val:
          let
            isNumber = c: elem c ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9"];
          in
          if (val == "") then "\"\""
            else if val == "y" || val == "m" || val == "n" then val
            else if all isNumber (stringToCharacters val) then val
            else if substring 0 2 val == "0x" then val
            else val # FIXME: fix quoting one day
          ;

          mkConfigLine = key: item:
            let
              val = if item.freeform != null then item.freeform else item.tristate;
            in
            if val == null then "# CONFIG_${key} is not set" else
            # TODO: Handle optional here??
            # This could only work if we are given the kernel version to work from.
            if (item.optional)
            then "CONFIG_${key}=${mkValue val}"
            else "CONFIG_${key}=${mkValue val}"
          ;

          mkConf = cfg: lib.concatStringsSep "\n" (lib.mapAttrsToList mkConfigLine cfg);
          configfile = mkConf config.settings;

          validatorSnippet = writeShellScript "kernel-configuration-validator-snippet" ''
            # Validation disabled to allow compiler-detected options to vary
            echo
            echo ":: Kernel configuration validation disabled"
            echo
            true
          '';
        in
        {
          options = {
            configfile = lib.mkOption {
              readOnly = true;
              type = lib.types.str;
              description = ''
                String that can directly be used as a kernel config file contents.
              '';
            };
            validatorSnippet = lib.mkOption {
              readOnly = true;
              type = lib.types.package;
              description = ''
                Path to a script that can directly be called to validate the kernel config.
              '';
            };
          };
          config = {
            inherit configfile validatorSnippet;
          };
        }
      )
      { settings = structuredConfig; _file = "(structuredConfig argument)"; }
    ] ++ modules;
  }).config;
}
