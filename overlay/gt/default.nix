{ stdenv
, fetchFromGitHub
, libconfig
, libusbgx
, cmake
, pkg-config
}:

stdenv.mkDerivation rec {
  pname = "gt";
  version = "git";

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    libconfig
    libusbgx
  ];

  sourceRoot = "${src.name}/source";

  src = fetchFromGitHub {
    owner = "linux-usb-gadgets";
    repo = "gt";
    rev = "8ebbf3eb6fb77a53d6ace0eebf4f5debb779b576";
    hash = "sha256-f/1nYnpAJ22ilWeyGtGcz9ZynL8a4UQoiKW+K/97iRI=";
  };

  patches = [
    ./patches/0001-cmake-Require-cmake-3.5.patch
    ./patches/0002-libusbg-Remove-deprecated-inquiry_string.patch
  ];
}
