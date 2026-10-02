{ lib
, fetchFromGitLab
, stdenv
, meson
, ninja
, pkg-config
, vala
, gobject-introspection
, glib
, gmobile
, modemmanager
, mobile-broadband-provider-info
}:

let
  gvdb = fetchFromGitLab {
    domain = "gitlab.gnome.org";
    owner = "GNOME";
    repo = "gvdb";
    rev = "c6f2359cc1d00f16e0a0e2527fa0bc1882b8b5ab";
    hash = "sha256-FQPctq+fj6du0sBawaJxtO0PRO0KIHHhdA2jh24Yacw=";
  };
in

stdenv.mkDerivation rec {
  pname = "cellbroadcastd";
  version = "0.0.3";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "devrtz";
    repo = "cellbroadcastd";
    rev = "v${version}";
    hash = "sha256-QMx/E631aWJIwvRDbzyrO9K+7xdd54ZbiE4Eoune3Co=";
  };

  preConfigure = ''
    cp -r ${gvdb} subprojects/gvdb
    chmod -R u+w subprojects/gvdb
  '';

  nativeBuildInputs = [ meson ninja pkg-config vala gobject-introspection ];
  buildInputs = [ glib gmobile modemmanager mobile-broadband-provider-info ];

  meta = with lib; {
    description = "Cell broadcast daemon for mobile Linux";
    homepage = "https://gitlab.freedesktop.org/devrtz/cellbroadcastd";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
