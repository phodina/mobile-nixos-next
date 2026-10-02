{ lib
, fetchFromGitLab
, stdenv
, meson
, ninja
, pkg-config
, wayland-scanner
, glib
, gtk3
, libhandy
, gmobile
, gnome-desktop
, gsettings-desktop-schemas
, json-glib
, feedbackd
, wayland
, wayland-protocols
, libxkbcommon
, systemd
}:

stdenv.mkDerivation rec {
  pname = "phosh-osk-stevia";
  version = "0.57.0";

  src = fetchFromGitLab {
    domain = "gitlab.gnome.org";
    owner = "World/Phosh";
    repo = "Stevia";
    rev = "v${version}";
    hash = "sha256-0hOjVojlUQLWTbsyejrP3sa79gb1ePeJlsXAhDvDijE=";
  };

  nativeBuildInputs = [ meson ninja pkg-config wayland-scanner ];

  buildInputs = [
    glib
    gtk3
    libhandy
    gmobile
    gnome-desktop
    gsettings-desktop-schemas
    json-glib
    feedbackd
    wayland
    wayland-protocols
    libxkbcommon
    systemd
  ];

  mesonFlags = [
    "-Dgnome_desktop=false"
    "-Dhunspell=disabled"
    "-Dpresage=disabled"
    "-Duim=disabled"
  ];

  meta = with lib; {
    description = "On-screen keyboard for Phosh";
    homepage = "https://gitlab.gnome.org/World/Phosh/Stevia";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
