{ lib
, pkgs
, name

# mkbootimg specific values
, kernel
, initrd
, cmdline
, bootimg
, appendDTB
# u-boot specific values
, ubootMode ? false
, ubootPackage ? null
}:

let
  inherit (lib) optionalString;
  inherit (pkgs) buildPackages;

  fitImage = if ubootMode then
    pkgs.callPackage ./../u-boot/fit-image.nix {
      name = "${name}-fit";
      inherit kernel;
      inherit initrd;
      dtbs = if appendDTB != null then appendDTB else [];
    }
  else null;
  
  # Determine the actual kernel and ramdisk to use
  actualKernel = if ubootMode then "${ubootPackage}/binaries/u-boot.bin" else kernel;
  actualRamdisk = if ubootMode then fitImage else initrd;
in
pkgs.runCommand name {
  nativeBuildInputs = with buildPackages; [
    mkbootimg
    dtbTool
  ];
  inherit kernel;
} ''
  PS4=" $ "
  ${if ubootMode then ''
    echo "U-Boot mode enabled"
    echo "Using U-Boot as kernel: ${ubootPackage}/binaries/u-boot.bin"
    echo "Using FIT image as ramdisk: ${fitImage}"
    kernel="${ubootPackage}/binaries/u-boot.bin"
    ramdisk="${fitImage}"
  '' else ''
    echo Using kernel: $kernel
    ${optionalString (appendDTB != null) ''
    kernel=$PWD/kernel-with-dtbs
    (
      cd $(dirname ${kernel})
      set -x
      cat ${kernel} ${lib.escapeShellArgs appendDTB} > $kernel
    )
    echo Using appended dtb kernel now...
    ''}
    ramdisk="${initrd}"
  ''}
  (
  set -x
  mkbootimg \
    --kernel  $kernel \
    ${optionalString (!ubootMode && bootimg.dt != null) "--dt ${bootimg.dt}"} \
    --ramdisk $ramdisk \
    --cmdline       "${cmdline}" \
    --base           ${bootimg.flash.offset_base   } \
    --kernel_offset  ${bootimg.flash.offset_kernel } \
    --second_offset  ${bootimg.flash.offset_second } \
    --ramdisk_offset ${bootimg.flash.offset_ramdisk} \
    --tags_offset    ${bootimg.flash.offset_tags   } \
    --pagesize       ${bootimg.flash.pagesize      } \
    -o $out
  )
''
