{ config, lib, pkgs, ... }:

let
  enabled = config.filesystem == "ext4";
  inherit (lib)
    escapeShellArg
    mkIf
    mkMerge
    mkOption
    optionalString
    types
  ;
  inherit (config.helpers)
    chopDecimal
  ;

  inherit (config) label;
  inherit (config.ext4) partitionID;

  # Bash doesn't do floating point representations. Multiplications and divisions
  # are handled with enough precision that we can multiply and divide to get a precision.
  precision = 1000;

  makeFudge = f: toString (chopDecimal (f * precision));

  # This applies only to 256MiB and greater.
  # For smaller than 256MiB images the overhead from the FS is much greater.
  # This will also let *some* slack space at the end at greater sizes.
  # This is the value at 512MiB where it goes slightly down compared to 256MiB.
  fudgeFactor = makeFudge 0.05208587646484375;

  # This table was built using a script that built an image with `make_ext4fs`
  # for the given size in MiB, and recorded the available size according to `df`.
  smallFudgeLookup = lib.strings.concatStringsSep "\n" (lib.lists.reverseList(
    lib.attrsets.mapAttrsToList (size: factor: ''
      elif (( size > ${toString size} )); then
        fudgeFactor=${toString factor}
    '') {
    "${toString (config.helpers.size.MiB   5)}" = makeFudge 0.84609375;
    "${toString (config.helpers.size.MiB   8)}" = makeFudge 0.5419921875;
    "${toString (config.helpers.size.MiB  16)}" = makeFudge 0.288818359375;
    "${toString (config.helpers.size.MiB  32)}" = makeFudge 0.1622314453125;
    "${toString (config.helpers.size.MiB  64)}" = makeFudge 0.09893798828125;
    "${toString (config.helpers.size.MiB 128)}" = makeFudge 0.067291259765625;
    "${toString (config.helpers.size.MiB 256)}" = makeFudge 0.0518646240234375;
  }
  ));

  minimumSize = config.helpers.size.MiB 5;
in
{
  options.ext4 = {
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
    { availableFilesystems = [ "ext4" ]; }
    (mkIf enabled {
      nativeBuildInputs = with pkgs.buildPackages; [
        e2fsprogs
        pkgs.buildPackages.libfaketime
        pkgs.buildPackages.perl
        pkgs.buildPackages.fakeroot
      ];

      blockSize = config.helpers.size.KiB 4;
      sectorSize = lib.mkDefault 512;

      inherit minimumSize;

      computeMinimalSize = ''
        # Using nixpkgs-style size calculation
        # Make a crude approximation of the size of the target image.
        # Based on nixos/lib/make-ext4-fs.nix

        echo "Calculating filesystem size based on content..." 1>&2

        numInodes=$(find . -type f -o -type d -o -type l | wc -l)
        numDataBlocks=$(du -s -c -B 4096 --apparent-size . | tail -1 | awk '{ print int($1 * 1.20) }')

        # Account for:
        # - 2 blocks per inode for metadata
        # - data blocks with 20% overhead
        size=$((2 * 4096 * numInodes + 4096 * numDataBlocks))

        echo "Calculated size: $size bytes (numInodes=$numInodes, numDataBlocks=$numDataBlocks)" 1>&2

        # Round up to the nearest mebibyte for proper alignment
        local mebibyte=$((1024 * 1024))
        if (( size % mebibyte )); then
          size=$(( (size / mebibyte + 1) * mebibyte ))
        fi

        # Ensure minimum size
        if (( size < ${toString minimumSize} )); then
          echo "Size $size is below minimum, using ${toString minimumSize}" 1>&2
          size=${toString minimumSize}
        fi

        echo "Final image size: $size bytes" 1>&2
      '';

      buildPhases = {
        copyPhase = ''
          # Create empty image file with calculated size
          echo "Creating EXT4 image of $size bytes"
          truncate -s $size "$img"

          # Format with mkfs.ext4 using nixpkgs standard approach
          # -L: volume label
          # -U: UUID
          # -i: bytes per inode (prevents inode exhaustion)
          # -d: populate from directory
          faketime -f "1970-01-01 00:00:01" fakeroot mkfs.ext4 \
            -i 16384 \
            ${optionalString (label != null) "-L ${escapeShellArg label}"} \
            ${optionalString (partitionID != null) "-U ${partitionID}"} \
            -d . \
            "$img"
        '';

        checkPhase = ''
          export EXT2FS_NO_MTAB_OK=yes

          # Verify filesystem integrity (as in nixpkgs)
          if ! faketime -f "1970-01-01 00:00:01" fsck.ext4 -n -f "$img"; then
            echo "--- Fsck failed for EXT4 image ---"
            return 1
          fi

          # Shrink filesystem to fit content (nixpkgs approach)
          echo "Shrinking filesystem to minimal size..."
          resize2fs -M "$img"

          # Add 16 MiB slack space for growth
          new_size=$(dumpe2fs -h "$img" | awk -F: \
            '/Block count/{count=$2} /Block size/{size=$2} END{print (count*size+16*2**20)/size}')

          echo "Resizing to $new_size blocks (with 16 MiB slack)..."
          resize2fs "$img" "$new_size"

          # Final verification
          faketime -f "1970-01-01 00:00:01" fsck.ext4 -n -f "$img"
        '';
      };
    })
  ];
}
