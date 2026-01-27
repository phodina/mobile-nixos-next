{ fetchFromGitHub,
  stdenv,
  findutils,
  pil-squasher,
  lib,
  ...
}:

stdenv.mkDerivation {
  pname = "fp5-firmware";
  version = "unstable-2026-01-09";

  src = fetchFromGitHub {
    owner = "FairBlobs";
    repo = "FP5-firmware";
    rev = "a4908f548e6f88965e78b1478af1751b6a854fc9";
    hash = "sha256-XRklo4XfRrskmIxdyY9duU8nF0svoQV90KwaF15ISjk=";
  };

  meta = {
    description = "Firmware files for Fairphone 5";
    longDescription = ''
      Proprietary firmware files required for Fairphone 5 hardware components
      including GPU, DSP, modem, and Bluetooth. Converted from Qualcomm split
      format to monolithic .mbn files for mainline Linux kernel.
    '';
    homepage = "https://github.com/FairBlobs/FP5-firmware";
    license = lib.licenses.unfree;
    maintainers = [ ];
    platforms = lib.platforms.linux;
  };

  nativeBuildInputs = [
    pil-squasher
    findutils
  ];


  buildPhase = ''
    runHook preBuild
    # Squash all .mdt firmware files to .mbn format.
    echo "Squashing firmware files..."
    find . -name "*.mdt" -type f -print0 | while IFS= read -r -d "" mdtfile; do
      echo "Processing: $mdtfile"
      pil-squasher "''${mdtfile%.mdt}.mbn" "$mdtfile"
    done
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    fwDir="$out/lib/firmware/qcom/qcm6490/fairphone5"
    qcaDir="$out/lib/firmware/qca"
    shareDir="$out/usr/share/qcom/qcm6490/Fairphone/fp5"

    install -Dm644 -t "$fwDir" \
      a660_zap.mbn \
      adsp.mbn \
      cdsp.mbn \
      modem.mbn \
      wpss.mbn \
      adspr.jsn \
      adsps.jsn \
      adspua.jsn \
      battmgr.jsn \
      cdspr.jsn \
      modemr.jsn

    install -Dm644 yupik_ipa_fws.mbn "$fwDir/ipa_fws.mbn"

    install -Dm644 vpu20_1v.mbn "$fwDir/venus.mbn"

    install -Dm644 -t "$qcaDir" \
      msbtfw11.mbn \
      msnv11.bin

    mkdir -p "$fwDir"
    cp -r modem_pr "$fwDir"

    find "$fwDir/modem_pr" -type f -exec chmod 0644 {} \;

    mkdir -p "$shareDir"

    cp -r hexagonfs/sensors "$shareDir"
    cp -r hexagonfs/socinfo "$shareDir"

    find "$shareDir" -type f -exec chmod 0644 {} \;

    runHook postInstall
  '';
}
