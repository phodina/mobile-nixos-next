{ stdenv, lib }:

stdenv.mkDerivation {
  pname = "firmware-sdm845-generic";
  version = "0.0.0";

  src = null;

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/lib/firmware/qcom/sdm845
    # Generic device - we rely on framebuffer so don't need firmware 
  '';

  meta = with lib; {
    description = "Placeholder firmware for SDM845 Generic device";
    license = licenses.unfreeRedistributableFirmware;
    platforms = platforms.linux;
  };
}
