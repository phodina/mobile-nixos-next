{ lib
, pkgs
, name
# mkbootimg specific values
, kernel
, initrd
, cmdline
, bootimg
, appendDTB ? null
# u-boot specific values
, uboot ? null
}:

let
  inherit (lib) optionalString optionalAttrs;
  inherit (pkgs) buildPackages;

  hasUboot = uboot != null;

  baseDir = builtins.dirOf kernel;

  resolveDtb = dtb:
    if lib.hasPrefix "/" dtb || lib.hasPrefix "/nix/store" dtb
    then dtb
    else "${baseDir}/${dtb}";

  fitImage = if hasUboot then
    pkgs.callPackage ./../u-boot/fit-image.nix {
      name = "${name}-fit";
      inherit kernel initrd;
      dtbs = if appendDTB != null then appendDTB else [];
    }
  else null;

  # Determine the actual kernel and ramdisk to use
  actualKernel = if hasUboot then "${uboot}/binaries/u-boot.bin" else kernel;
  actualRamdisk = if hasUboot then fitImage else initrd;

  # Prepare kernel with DTB if needed
  kernelWithDtb = if (!hasUboot && appendDTB != null) then
    pkgs.runCommand "${name}-kernel-with-dtb" {} ''
      cat ${kernel} ${lib.concatStringsSep " " (map (dtb: resolveDtb dtb) appendDTB)} > $out
    ''
  else null;

  finalKernel = if kernelWithDtb != null then kernelWithDtb else actualKernel;
in
pkgs.runCommand name {
  nativeBuildInputs = with buildPackages; [
    mkbootimg
    dtbTool
  ];

  passthru = {
    inherit kernel initrd hasUboot;
  } // optionalAttrs hasUboot {
    inherit uboot fitImage;
  };
} ''
  mkbootimg \
    --kernel ${finalKernel} \
    ${optionalString (!hasUboot && bootimg.dt != null) "--dt ${bootimg.dt}"} \
    --ramdisk ${actualRamdisk} \
    --cmdline "${cmdline}" \
    --base ${bootimg.flash.offset_base} \
    --kernel_offset ${bootimg.flash.offset_kernel} \
    --second_offset ${bootimg.flash.offset_second} \
    --ramdisk_offset ${bootimg.flash.offset_ramdisk} \
    --tags_offset ${bootimg.flash.offset_tags} \
    --pagesize ${bootimg.flash.pagesize} \
    -o $out
''
