{ lib
, fetchFromGitHub
, python3Packages
, meson
, ninja
, pkg-config
, cmake
, blueprint-compiler
, wrapGAppsHook4
, desktop-file-utils
, gtk4
, libadwaita
, glib
, libzint
}:

python3Packages.buildPythonApplication rec {
  pname = "passes-gtk";
  version = "0.12";

  src = fetchFromGitHub {
    owner = "pablo-s";
    repo = "passes";
    rev = "v${version}";
    hash = "sha256-S+TEZQu7Ye+hBqzSJP/YEik35b+4LQrnk2A/hhTjpww=";
  };

  format = "other";

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    cmake
    blueprint-compiler
    wrapGAppsHook4
    desktop-file-utils
    python3Packages.setuptools
  ];

  buildInputs = [ gtk4 libadwaita glib libzint ];

  meta = with lib; {
    description = "Manage digital passes (PKPASS) on GNOME mobile";
    homepage = "https://github.com/pablo-s/passes";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
