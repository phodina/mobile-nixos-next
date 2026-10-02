{ lib
, fetchFromGitLab
, stdenv
, meson
, ninja
, pkg-config
, blueprint-compiler
, wrapGAppsHook4
, glib
, gtk4
, gnome-desktop
, gsettings-desktop-schemas
, xdg-desktop-portal
, fontconfig
, gdk-pixbuf
}:

stdenv.mkDerivation rec {
  pname = "xdg-desktop-portal-phosh";
  version = "0.57.0";

  src = fetchFromGitLab {
    domain = "gitlab.gnome.org";
    owner = "World/Phosh";
    repo = "xdg-desktop-portal-phosh";
    rev = "v${version}";
    hash = "sha256-f8jPq/KBP6JPOEGbgeWL1yv+BnOEqgJ+6j1wosCvD4c=";
  };

  nativeBuildInputs = [ meson ninja pkg-config blueprint-compiler wrapGAppsHook4 ];

  buildInputs = [
    glib
    gtk4
    gnome-desktop
    gsettings-desktop-schemas
    xdg-desktop-portal
    fontconfig
    gdk-pixbuf
  ];

  meta = with lib; {
    description = "XDG desktop portal backend for Phosh";
    homepage = "https://gitlab.gnome.org/World/Phosh/xdg-desktop-portal-phosh";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
