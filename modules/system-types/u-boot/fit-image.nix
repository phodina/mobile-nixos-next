{ lib
, pkgs
, name
, kernel
, initrd
, dtbs ? []
}:

let
  inherit (pkgs) buildPackages;
  inherit (lib) concatMapStringsSep;
  
  baseDir = builtins.dirOf kernel;

  resolveDtb = dtb:
    if lib.hasPrefix "/" dtb || lib.hasPrefix "/nix/store" dtb
    then dtb
    else "${baseDir}/${dtb}";
  
  fdtEntries = lib.imap0 (idx: dtb: let
    resolvedDtb = resolveDtb dtb;
  in ''
    fdt-${toString idx} {
      description = "Device Tree ${toString idx}";
      data = /incbin/("${resolvedDtb}");
      type = "flat_dt";
      arch = "arm64";
      compression = "none";
      hash-1 {
        algo = "sha256";
      };
    };
  '') dtbs;
  
  configEntries = lib.imap0 (idx: dtb: ''
    config-${toString idx} {
      description = "Configuration ${toString idx}";
      kernel = "kernel";
      ramdisk = "ramdisk";
      fdt = "fdt-${toString idx}";
    };
  '') dtbs;
  
  defaultConfig = if dtbs != [] then "config-0" else null;
  
  itsContent = ''
    /dts-v1/;
    
    / {
      description = "Mobile NixOS FIT Image";
      #address-cells = <1>;
      
      images {
        kernel {
          description = "Linux Kernel";
          data = /incbin/("${kernel}");
          type = "kernel";
          arch = "arm64";
          os = "linux";
          compression = "none";
          load = <0x01080000>;
          entry = <0x01080000>;
          hash-1 {
            algo = "sha256";
          };
        };
        
        ramdisk {
          description = "Initrd";
          data = /incbin/("${initrd}");
          type = "ramdisk";
          arch = "arm64";
          os = "linux";
          compression = "none";
          hash-1 {
            algo = "sha256";
          };
        };
        
        ${concatMapStringsSep "\n    " (x: x) fdtEntries}
      };
      
      ${lib.optionalString (dtbs != []) ''
      configurations {
        ${lib.optionalString (defaultConfig != null) ''
        default = "${defaultConfig}";
        ''}
        
        ${concatMapStringsSep "\n    " (x: x) configEntries}
      };
      ''}
    };
  '';
  
in
pkgs.runCommand "${name}-fit" {
  nativeBuildInputs = with buildPackages; [
    ubootTools
    dtc
  ];
  passAsFile = [ "itsContent" ];
  inherit itsContent;
} ''
  cp "$itsContentPath" image.its
  
  mkimage -f image.its $out
  
  echo "FIT image created: $out"
  ls -lh $out
''
