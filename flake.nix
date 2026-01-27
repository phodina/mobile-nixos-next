{
  description = "Mobile NixOS - NixOS on mobile devices";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    microhop.url = "github:phodina/microhop/7c5455a6c6045ced169a04acf8eaf99e06ff2d39";
  };

  outputs = { self, nixpkgs, microhop }:
    let
      system = "aarch64-linux";

      microhopOverlay = final: prev: {
        microhop = microhop.packages.${system}.microhop or (throw "microhop package not found in microhop flake");
        microgen = microhop.packages.${system}.microgen or (throw "microgen package not found in microhop flake");
      };

      overlays = [
        microhopOverlay
        (import ./overlay/overlay.nix)
      ];

      pkgs = import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      };

      devicesDir = ./devices;
      deviceNames = builtins.filter
        (name: name != "families" && builtins.pathExists (devicesDir + "/${name}/default.nix"))
        (builtins.attrNames (builtins.readDir devicesDir));

      buildDevice = deviceName:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = (import ./modules/module-list.nix) ++ [
            (devicesDir + "/${deviceName}")
            {
              mobile.enable = true;
              networking.hostName = deviceName;
              system.stateVersion = "25.11";

              nixpkgs = {
                inherit overlays;
                config.allowUnfree = true;
              };
            }
          ];
        };

      devices = builtins.listToAttrs (map (name: {
        name = name;
        value = buildDevice name;
      }) deviceNames);

    in {
      nixosConfigurations = devices;
      
      packages = forAllSystems (system: packagesForSystem system);
    };
}
