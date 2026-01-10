{ lib
, fetchFromGitHub
, device ? "qualcomm-sdm845"
, variant ? "androidboot"
}:

let
  # Fetch Tow-Boot source from GitHub
  towBootSrc = fetchFromGitHub {
    owner = "phodina";
    repo = "Tow-Boot";
    rev = "main"; # You can pin to a specific commit/tag later
    sha256 = lib.fakeSha256; # Will need to update after first build
  };
  
  # Build Tow-Boot using its native build system
  towBootBuild = (import towBootSrc {
    device = device;
    configuration = {
      # Override to use the androidboot variant (abootimg)
      Tow-Boot.variant = lib.mkForce variant;
    };
    silent = true;
  }).${device};

  # Get the firmware output
  firmware = towBootBuild.config.Tow-Boot.outputs.firmware;

in
# Return a derivation that exposes the binaries in a convenient way
firmware.overrideAttrs (oldAttrs: {
  pname = "tow-boot-${device}-${variant}";
  
  # Add a postInstall to create convenience symlinks
  postInstall = (oldAttrs.postInstall or "") + ''
    # Create a symlink to u-boot-nodtb.bin at the top level for easy reference
    if [ -f "$out/binaries/u-boot-nodtb.bin" ]; then
      ln -sf binaries/u-boot-nodtb.bin $out/u-boot-nodtb.bin
      echo "✓ u-boot-nodtb.bin available at: $out/u-boot-nodtb.bin"
    else
      echo "⚠ Warning: u-boot-nodtb.bin not found in firmware output"
      echo "Available files in $out/binaries:"
      ls -la $out/binaries/ || true
    fi
  '';

  passthru = (oldAttrs.passthru or {}) // {
    # Convenience accessors for derivation outputs
    inherit firmware;
    inherit (towBootBuild) config;
    
    # Path to u-boot-nodtb.bin for use in other derivations
    ubootNodtb = "${firmware}/binaries/u-boot-nodtb.bin";
  };

  meta = (oldAttrs.meta or {}) // {
    description = "Tow-Boot bootloader for ${device} (${variant} variant)";
    homepage = "https://github.com/phodina/Tow-Boot";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
})
