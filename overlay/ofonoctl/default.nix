{ lib
, fetchPypi
, python3Packages
}:

python3Packages.buildPythonApplication rec {
  pname = "ofonoctl";
  version = "0.4.1";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-ZLsJvpt89ZMY4P+eRt/OEnx9vpBXQ38Y/VTWxoS0D3o=";
  };

  pyproject = true;
  build-system = with python3Packages; [ setuptools ];

  dependencies = with python3Packages; [
    dbus-python
    tabulate
  ];

  meta = with lib; {
    description = "Test/control application for the ofono daemon";
    homepage = "https://git.sr.ht/~martijnbraam/ofonoctl";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
