{ lib
, fetchFromGitHub
, stdenv
, meson
, ninja
, pkg-config
, glib
}:

stdenv.mkDerivation rec {
  pname = "hexagonrpcd";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "linux-msm";
    repo = "hexagonrpc";
    rev = "v${version}";
    hash = "sha256-njhDLpkEuA2PSPe9rpYvlDN4JLgkYCfgZ5oX/NFx2Ho=";
  };

  nativeBuildInputs = [ meson ninja pkg-config ];
  buildInputs = [ glib ];

  meta = with lib; {
    description = "Server for FastRPC remote procedure calls from Qualcomm DSPs";
    homepage = "https://github.com/linux-msm/hexagonrpc";
    license = licenses.bsd3;
    platforms = [ "aarch64-linux" ];
  };
}
