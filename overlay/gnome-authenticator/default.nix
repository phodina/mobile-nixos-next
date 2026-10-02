{ lib
, fetchFromGitLab
, rustPlatform
, pkg-config
, gtk4
, libadwaita
, glib
, zbar
, gettext
, openssl
, wrapGAppsHook4
, gst_all_1
, sqlite
}:

rustPlatform.buildRustPackage rec {
  pname = "gnome-authenticator";
  version = "4.6.2";

  src = fetchFromGitLab {
    domain = "gitlab.gnome.org";
    owner = "World";
    repo = "Authenticator";
    rev = version;
    hash = "sha256-UvHIVUed4rxmjliaZ7jnwCjiHyvUDihoJyG3G+fYtow=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };

  postPatch = ''
    cat > src/config.rs << 'EOF'
pub static APP_ID: &str = "com.belmoussaoui.Authenticator";
pub static PKGDATADIR: &str = "/usr/share/authenticator";
pub static PROFILE: &str = "";
pub static VERSION: &str = "4.6.2";
pub static GETTEXT_PACKAGE: &str = "authenticator";
pub static LOCALEDIR: &str = "/usr/share/locale";
pub static OBJECT_PATH: &str = "/com/belmoussaoui/Authenticator/SearchProvider";
EOF
  '';

  nativeBuildInputs = [ pkg-config gettext wrapGAppsHook4 ];
  buildInputs = [ gtk4 libadwaita glib zbar openssl sqlite gst_all_1.gstreamer gst_all_1.gst-plugins-base ];

  doCheck = false;

  meta = with lib; {
    description = "Two-factor authentication code generator for GNOME";
    homepage = "https://gitlab.gnome.org/World/Authenticator";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
