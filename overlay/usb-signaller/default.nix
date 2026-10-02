{ lib
, fetchFromGitea
, rustPlatform
, pkg-config
, udev
}:

rustPlatform.buildRustPackage rec {
  pname = "usb-signaller";
  version = "0.4.2";

  src = fetchFromGitea {
    domain = "codeberg.org";
    owner = "DylanVanAssche";
    repo = "usb-signaller";
    rev = "v0.4.2";
    hash = "sha256-c4wI6sHHiCad18t62dD9SEgdmoo0S+BO22wUGytIJ0Q=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };

  doCheck = false;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ udev ];

  postInstall = ''
    install -Dm644 com.meego.usb_moded.conf \
      $out/share/dbus-1/system.d/com.meego.usb_moded.conf
    install -Dm644 usb-signaller.service \
      $out/lib/systemd/system/usb-signaller.service
    for f in distro/systemd/*.service; do
      install -Dm644 "$f" "$out/lib/systemd/system/$(basename $f)"
    done
  '';

  meta = with lib; {
    description = "Replacement for usb-moded on mainline Linux mobile devices";
    homepage = "https://codeberg.org/DylanVanAssche/usb-signaller";
    license = licenses.gpl3Plus;
    maintainers = [];
    platforms = platforms.linux;
  };
}
