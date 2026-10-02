{ lib
, fetchFromGitLab
, stdenv
, meson
, ninja
, pkg-config
, blueprint-compiler
, wrapGAppsHook4
, gtk4
, libadwaita
, libshumate
, glib
, geocode-glib_2
, libgweather
, geoclue2
}:

stdenv.mkDerivation rec {
  pname = "picplanner";
  version = "0.5.4";

  src = fetchFromGitLab {
    owner = "Zwarf";
    repo = "picplanner";
    rev = "v${version}";
    hash = "sha256-pDsm/IZQuXLAOOWDyL6lJ/W4uE7bX6YtfW1do4ELpBA=";
  };

  postPatch = ''
    sed -i "s/gtk-update-icon-cache/true/g; s/update-desktop-database/true/g" build-aux/meson/postinstall.py
  '';

  nativeBuildInputs = [ meson ninja pkg-config blueprint-compiler wrapGAppsHook4 ];
  buildInputs = [ gtk4 libadwaita libshumate glib geocode-glib_2 libgweather geoclue2 ];

  meta = with lib; {
    description = "Plan photo sessions by calculating sun, moon and Milky Way positions";
    homepage = "https://gitlab.com/Zwarf/picplanner";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
