{ lib
, fetchFromGitLab
, rustPlatform
, pkg-config
, glib
, gtk4
, libadwaita
, gettext
}:

rustPlatform.buildRustPackage rec {
  pname = "pfs";
  version = "0.1.2";

  src = fetchFromGitLab {
    domain = "gitlab.gnome.org";
    owner = "World/Phosh";
    repo = "pfs";
    rev = "v${version}";
    hash = "sha256-LIwWSNYIYAKt61Iot8ltrfmEWsLX1qCn+ry117vaM9o=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };

  cargoBuildFlags = [ "--bin" "pfs-open" ];

  nativeBuildInputs = [ pkg-config gettext glib ];
  buildInputs = [ gtk4 libadwaita ];

  doCheck = false;

  meta = with lib; {
    description = "Phosh session services";
    homepage = "https://gitlab.gnome.org/World/Phosh/pfs";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
