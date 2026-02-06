{ stdenv, lib, emptyDirectory }:

stdenv.mkDerivation {
  pname = "firmware-sdm845-generic";
  version = "0.0.0";

  src = emptyDirectory;
}
