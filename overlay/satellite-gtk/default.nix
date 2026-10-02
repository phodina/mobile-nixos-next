{ lib
, fetchFromGitea
, python3Packages
, wrapGAppsHook4
, gtk4
, libadwaita
}:

python3Packages.buildPythonApplication rec {
  pname = "satellite-gtk";
  version = "0.9.2";
  pyproject = true;

  src = fetchFromGitea {
    domain = "codeberg.org";
    owner = "tpikonen";
    repo = "satellite";
    rev = version;
    hash = "sha256-DubLxsqJsvCbfFD9jNkKHGd2Ur/bT7Ea5bHLijciwtI=";
  };

  nativeBuildInputs = with python3Packages; [
    setuptools
    wrapGAppsHook4
  ];

  dependencies = with python3Packages; [
    pygobject3
    pydbus
    pynmea2
    gpxpy
  ];

  buildInputs = [ gtk4 libadwaita ];

  meta = with lib; {
    description = "GNSS information viewer for mobile Linux";
    homepage = "https://codeberg.org/tpikonen/satellite";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
