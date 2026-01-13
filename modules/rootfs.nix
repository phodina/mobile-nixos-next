# This provides `build.rootfs`, which is the rootfs image (ext4) built from
# the current configuration.
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkOption optionalString types;
  inherit (config.mobile._internal) compressLargeArtifacts;
  inherit (pkgs) buildPackages;
  rootfsLabel = config.mobile.generatedFilesystems.rootfs.label;
in
{
  options = {
    mobile = {
      rootfs = {
        enableDefaultConfiguration = mkOption {
          type = types.bool;
          default = config.mobile.enable;
          description = ''
            Whether some of the rootfs configuration is managed by Mobile NixOS or not.
          '';
        };
        rehydrateStore = mkOption {
          type = types.bool;
          default = config.nix.enable;
          defaultText = lib.literalExpression "config.nix.enable";
          description = ''
            Whether to rehydrate the store at first boot or not.

            The only reason you would disable this is to build a target system that has no Nix binaries.
          '';
        };
        sparse = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to convert the rootfs image to sparse Android format using img2simg.

            When enabled, the original ext4 image will be converted to a sparse image
            and the original will be discarded. This is useful for flashing to Android
            devices where sparse images are expected.
          '';
        };
        shrinkImage = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Whether to shrink the ext4 rootfs image to its minimum size after copying the closure.

            This significantly reduces the image size by removing unused space. The filesystem
            will automatically grow to fill available space on first boot (if growPartition is enabled).
            This is particularly useful when combined with sparse image conversion.
          '';
        };
      };
    };
  };

  config = mkIf (config.mobile.rootfs.enableDefaultConfiguration) {
    boot.growPartition = lib.mkDefault true;

    mobile.generatedFilesystems.rootfs = lib.mkDefault {
      filesystem = "ext4";
      label = "NIXOS_SYSTEM";
      ext4.partitionID = "44444444-4444-4444-8888-888888888888";

      populateCommands =
      let
        closureInfo = pkgs.buildPackages.closureInfo { rootPaths = config.system.build.toplevel; };
      in
      ''
        mkdir -p ./nix/store
        echo "Copying system closure..."

        err=0
        while IFS= read -r path; do
          echo "  Copying $path"
          if test -e "$path"; then
            cp -prf "$path" ./nix/store
          else
            2>&1 printf "ERROR: path %q does not exist...\n" "$path"
            (( ++err ))
          fi
        done < "${closureInfo}/store-paths"

        if (( err > 0 )); then
          2>&1 printf "... Bailing out, %d errors.\n" "$err"
          exit 2
        fi

        echo "Done copying system closure..."
        cp -v ${closureInfo}/registration ./nix-path-registration
      '';

      # Give some headroom for initial mounting.
      extraPadding = pkgs.image-builder.helpers.size.MiB 20;

      location = "/rootfs.img${optionalString compressLargeArtifacts ".zst"}";

      # FIXME: See #117, move compression into the image builder.
      # Zstd can take a long time to complete successfully at high compression
      # levels. Increasing the compression level could lead to timeouts.
      additionalCommands = 
        # Shrink image to minimum size
        optionalString config.mobile.rootfs.shrinkImage ''
          echo ":: Shrinking rootfs image to minimum size"
          (PS4=" $ "; set -x
          cd $out_path
          
          echo "   Checking filesystem..."
          ${buildPackages.e2fsprogs}/bin/e2fsck -fy "$img" || true
          
          echo "   Getting minimum filesystem size..."
          MIN_BLOCKS=$(${buildPackages.e2fsprogs}/bin/resize2fs -P "$img" 2>&1 | ${buildPackages.gnugrep}/bin/grep -oP 'minimum.*?: \K[0-9]+')
          
          echo "   Minimum blocks: $MIN_BLOCKS"
          
          # Add 5% safety margin to minimum size
          SAFETY_MARGIN=$(( MIN_BLOCKS * 5 / 100 ))
          TARGET_BLOCKS=$(( MIN_BLOCKS + SAFETY_MARGIN ))
          
          echo "   Target blocks (with 5% margin): $TARGET_BLOCKS"
          
          echo "   Shrinking filesystem to target size..."
          ${buildPackages.e2fsprogs}/bin/resize2fs -f "$img" "''${TARGET_BLOCKS}"
          
          echo "   Getting block size..."
          BLOCK_SIZE=$(${buildPackages.e2fsprogs}/bin/dumpe2fs -h "$img" 2>/dev/null | ${buildPackages.gawk}/bin/awk '/Block size/ {print $3}')
          
          FS_SIZE_BYTES=$(( TARGET_BLOCKS * BLOCK_SIZE ))
          FS_SIZE_MB=$(( FS_SIZE_BYTES / 1024 / 1024 ))
          
          echo "   Filesystem size ≈ ''${FS_SIZE_MB}MB (''${FS_SIZE_BYTES} bytes)"
          
          echo "   Truncating image file to exact size..."
          ${buildPackages.coreutils}/bin/truncate -s "''${FS_SIZE_BYTES}" "$img"
          
          echo "   Final filesystem check..."
          ${buildPackages.e2fsprogs}/bin/e2fsck -fy "$img" || true
          
          echo "   Done. Image shrunk to ''${FS_SIZE_MB}MB"
          )
        '' +
        # Sparse image conversion
        optionalString config.mobile.rootfs.sparse ''
          echo ":: Converting rootfs to sparse Android format"
          (PS4=" $ "; set -x
          cd $out_path
          
          # Convert to sparse format using android-tools from nixpkgs
          ${buildPackages.android-tools}/bin/img2simg "$img" "$img.sparse"
          # Replace the original image with the sparse version
          mv "$img.sparse" "$img"
          )
        '' +
        # Compression (if enabled)
        optionalString compressLargeArtifacts ''
          echo ":: Compressing rootfs image"
          (PS4=" $ "; set -x
          cd $out_path
          # Hacky, but the img path here already has .zst appended.
          # Let's rename it (we assume rootfs.img) and do the compression here.
          mv "$img" "rootfs.img"
          time ${buildPackages.zstd}/bin/zstd -10 --rm "rootfs.img"
          )
        '' + ''
          echo ":: Adding hydra-build-products"
          (PS4=" $ "; set -x
          mkdir -p $out_path/nix-support
          cat <<EOF > $out_path/nix-support/hydra-build-products
          file rootfs${optionalString config.mobile.rootfs.sparse "-sparse"}${optionalString compressLargeArtifacts "-zstd"} $img
          EOF
          )
        '';
    };

    boot.postBootCommands = mkIf (config.mobile.rootfs.rehydrateStore) ''
      # On the first boot do some maintenance tasks
      if [ -f /nix-path-registration ]; then
        # Register the contents of the initial Nix store
        ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration

        # nixos-rebuild also requires a "system" profile and an /etc/NIXOS tag.
        touch /etc/NIXOS
        ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system

        # Prevents this from running on later boots.
        rm -f /nix-path-registration
      fi
    '';

    fileSystems = {
      "/" = lib.mkDefault {
        device = "/dev/disk/by-label/${rootfsLabel}";
        fsType = "ext4";
        autoResize = true;
      };
    };

    # FIXME: Move this in a proper module + task for the filesystem.
    # This is a "wrong" assumption, that only holds through since we are setting
    # fileSystems."/".autoResize to true here.
    mobile.boot.stage-1.extraUtils = [
      { package = pkgs.e2fsprogs; }
    ];
  };
}
