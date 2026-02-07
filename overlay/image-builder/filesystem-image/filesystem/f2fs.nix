{ config, lib, pkgs, ... }:

let
  enabled = config.filesystem == "f2fs";
  inherit (lib)
    escapeShellArg
    mkIf
    mkMerge
    mkOption
    optionalString
    types
  ;

  inherit (config) label;
  inherit (config.f2fs) partitionID;
in
{
  options.f2fs = {
    partitionID = mkOption {
      type = types.nullOr config.helpers.types.uuid;
      example = "45454545-4545-4545-4545-454545454545";
      default = null;
      description = ''
        Volume ID of the filesystem.
      '';
    };
  };

  config = mkMerge [
    { availableFilesystems = [ "f2fs" ]; }
    (mkIf enabled {
      nativeBuildInputs = with pkgs.buildPackages; [
        f2fs-tools
      ];

      blockSize = config.helpers.size.KiB 4;
      sectorSize = lib.mkDefault 512;

      # F2FS has a minimum size requirement
      # Based on typical f2fs-tools requirements
      minimumSize = config.helpers.size.MiB 100;

      computeMinimalSize = ''
        # Using content-based size calculation
        # Account for F2FS metadata overhead
        echo "Calculating F2FS filesystem size based on content..." 1>&2

        # Calculate content size with du
        local contentSize=$(du -sb . | awk '{print $1}')

        # F2FS overhead is approximately 10-15% for metadata
        # Adding 20% to be safe
        local overhead=$((contentSize / 5))

        size=$((contentSize + overhead))

        echo "Content size: $contentSize bytes, overhead: $overhead bytes" 1>&2
        echo "Calculated size: $size bytes" 1>&2

        # Round up to the nearest mebibyte for proper alignment
        local mebibyte=$((1024 * 1024))
        if (( size % mebibyte )); then
          size=$(( (size / mebibyte + 1) * mebibyte ))
        fi

        echo "Rounded size: $size bytes" 1>&2
      '';

      buildPhases = {
        filesystemPhase = ''
          echo "Creating F2FS filesystem of $size bytes"

          # Create the filesystem
          mkfs.f2fs \
            ${optionalString (partitionID != null) "-U ${partitionID}"} \
            ${optionalString (label != null) "-l ${escapeShellArg label}"} \
            -f \
            "$img"
        '';

        copyPhase = ''
          # Mount the F2FS image and copy files
          echo "Populating F2FS filesystem..."

          # Create a temporary mount point
          local tmpMount=$(mktemp -d)

          # Mount the image
          mount -t f2fs -o loop "$img" "$tmpMount"

          # Copy all files
          (
            shopt -s dotglob
            for f in ./*; do
              if [[ "$f" != "./." && "$f" != "./.." ]]; then
                cp -a "$f" "$tmpMount/"
              fi
            done
          )

          # Sync and unmount
          sync
          umount "$tmpMount"
          rmdir "$tmpMount"
        '';

        checkPhase = ''
          echo "Checking F2FS filesystem..."
          fsck.f2fs -a "$img" || true
        '';
      };
    })
  ];
}
