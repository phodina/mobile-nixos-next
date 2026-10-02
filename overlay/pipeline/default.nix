{ lib
, fetchFromGitLab
, rustPlatform
, pkg-config
, gtk4
, libadwaita
, glib
, gettext
, openssl
, wrapGAppsHook4
, gst_all_1
, clapper-unwrapped
, blueprint-compiler
, sqlite
}:

rustPlatform.buildRustPackage rec {
  pname = "pipeline";
  version = "4.1.0";

  src = fetchFromGitLab {
    owner = "schmiddi-on-mobile";
    repo = "pipeline";
    rev = version;
    hash = "sha256-8/UMZGXCwqUw1EL7QFnpRqtSA6D9sU1ycG+AeHNeaXw=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    outputHashes = {
      "piped-openapi-sdk-1.0.0" = "sha256-8kxu6A/wQZYomNHXEDHEqyVuz0vOzEt25s8OJ/r284w=";
      "rustypipe-0.11.4" = "sha256-B4K0yp8xarPlTB4iS10lRXNUKYsa0cTVk2XTJRP0kh8=";
    };
  };

  postPatch = ''
    # Compile blueprint UI files
    blueprint-compiler batch-compile data/resources/ui data/resources/ui \
      $(find data/resources/ui -name "*.blp")

    # Generate metainfo XML
    sed 's/@app-id@/de.schmidhuberj.tubefeeder/g' \
      data/de.schmidhuberj.tubefeeder.metainfo.xml.in.in \
      > data/resources/de.schmidhuberj.tubefeeder.metainfo.xml

    # Generate gresource XML from template
    sed 's/@app-id@/de.schmidhuberj.tubefeeder/g' \
      data/resources/resources.gresource.xml.in \
      > data/resources/resources.gresource.xml

    # Compile gresources
    mkdir -p nix-gresource
    glib-compile-resources \
      --sourcedir data/resources \
      --target nix-gresource/resources.gresource \
      data/resources/resources.gresource.xml

    # Generate config.rs
    cat > src/config.rs << 'EOF'
pub const APP_ID: &str = "de.schmidhuberj.tubefeeder";
pub const BASE_ID: &str = "de.schmidhuberj.tubefeeder";
pub const GETTEXT_PACKAGE: &str = "pipeline";
pub const RESOURCES_PATH: &str = "/usr/share/pipeline";
pub const LOCALEDIR: &str = "/usr/share/locale";
pub const PROFILE: &str = "";
pub const FLATPAK: bool = false;
pub const RESOURCES_BYTES: &[u8] = include_bytes!("../nix-gresource/resources.gresource");
pub const NUMBER_OF_COMMITS: i64 = 0;
pub const NUMBER_OF_TAGS: i64 = 0;
pub const LINES_OF_RUST: i64 = 0;
pub const LINES_OF_BLUEPRINT: i64 = 0;
pub const NUMBER_OF_TRANSLATED_LANGUAGES: i64 = 0;
pub const NUMBER_OF_TRANSLATORS: i64 = 0;
EOF
  '';

  nativeBuildInputs = [ pkg-config gettext wrapGAppsHook4 blueprint-compiler glib ];
  buildInputs = [ gtk4 libadwaita glib openssl sqlite gst_all_1.gstreamer gst_all_1.gst-plugins-base clapper-unwrapped ];

  doCheck = false;

  meta = with lib; {
    description = "Watch YouTube, PeerTube and more in one place";
    homepage = "https://gitlab.com/schmiddi-on-mobile/pipeline";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
