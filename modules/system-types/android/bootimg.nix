{ lib
, pkgs
, name
# mkbootimg specific values
, kernel
, initrd
, cmdline
, bootimg
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

  # Determine if we should append DTB (header v0/v1) or use --dtb flag (header v2+)
  headerVersion = if bootimg.header_version != null then lib.toInt bootimg.header_version else 0;
  shouldAppendDtb = headerVersion < 2;

  # Normalize bootimg.dtb to a list for appending, or a single value for --dtb flag
  dtbList = if bootimg.dtb != null then
    (if lib.isList bootimg.dtb then bootimg.dtb else [bootimg.dtb])
  else [];

  dtbFile = if bootimg.dtb != null && !lib.isList bootimg.dtb then
    bootimg.dtb
  else if bootimg.dtb != null && lib.isList bootimg.dtb && lib.length bootimg.dtb > 0 then
    lib.head bootimg.dtb
  else null;

  fitImage = if hasUboot then
    pkgs.callPackage ./../u-boot/fit-image.nix {
      name = "${name}-fit";
      inherit kernel initrd;
      dtbs = dtbList;
    }
  else null;

  # Determine the actual kernel and ramdisk to use
  actualKernel = if hasUboot then "${uboot}/binaries/u-boot.bin" else kernel;
  actualRamdisk = if hasUboot then fitImage else initrd;

  # Prepare kernel with DTB if needed (for header v0/v1 DTB appending)
  kernelWithDtb = if (!hasUboot && shouldAppendDtb && bootimg.dtb != null) then
    pkgs.runCommand "${name}-kernel-with-dtb" {} ''
      cat ${kernel} ${lib.concatStringsSep " " (map (dtb: resolveDtb dtb) dtbList)} > $out
    ''
  else null;

  finalKernel = if kernelWithDtb != null then kernelWithDtb else actualKernel;

  # Resolve dtb file for header v2+
  finalDtbFile = if (!shouldAppendDtb && dtbFile != null) then resolveDtb dtbFile else null;
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
    --ramdisk ${actualRamdisk} \
    --cmdline "${cmdline}" \
    --base ${bootimg.flash.offset_base} \
    --kernel_offset ${bootimg.flash.offset_kernel} \
    --second_offset ${bootimg.flash.offset_second} \
    --ramdisk_offset ${bootimg.flash.offset_ramdisk} \
    --tags_offset ${bootimg.flash.offset_tags} \
    --pagesize ${bootimg.flash.pagesize} \
    ${optionalString (bootimg.header_version != null) "--header_version ${bootimg.header_version}"} \
    ${optionalString (bootimg.os_version != null) "--os_version ${bootimg.os_version}"} \
    ${optionalString (bootimg.os_patch_level != null) "--os_patch_level ${bootimg.os_patch_level}"} \
    ${optionalString (finalDtbFile != null) "--dtb ${finalDtbFile}"} \
    ${optionalString (bootimg.dtb_offset != null) "--dtb_offset ${bootimg.dtb_offset}"} \
    -o $out
''
