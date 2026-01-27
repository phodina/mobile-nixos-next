{
  description = "Mobile NixOS - NixOS on mobile devices";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    microhop.url = "github:phodina/microhop/7c5455a6c6045ced169a04acf8eaf99e06ff2d39";
  };

  outputs = { self, nixpkgs, microhop }:
    let
      # Support both aarch64-linux and x86_64-linux as build systems
      supportedSystems = [ "aarch64-linux" "x86_64-linux" ];

      # Helper to generate per-system outputs
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Generate packages for a given build system
      packagesForSystem = system:
        let
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
          allDeviceNames = builtins.filter
            (name: name != "families" && builtins.pathExists (devicesDir + "/${name}/default.nix"))
            (builtins.attrNames (builtins.readDir devicesDir));

          # Filter devices by target architecture
          # For x86_64-linux build system: only include x86_64 target devices (uefi-x86_64)
          # For aarch64-linux build system: include all devices
          deviceNames = if system == "x86_64-linux"
            then builtins.filter (name: builtins.match ".*x86_64.*" name != null) allDeviceNames
            else allDeviceNames;

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

        in builtins.listToAttrs (
          pkgs.lib.flatten (
            [
              { name = "microhop"; value = microhop.packages.${system}.microhop; }
              { name = "microgen"; value = microhop.packages.${system}.microgen; }
            ] ++
            (map (deviceName:
              let
                config = devices.${deviceName}.config;
                outputs = config.mobile.outputs;
              in [
                {
                  name = deviceName;
                  value = outputs.default;
                }
                {
                  name = "${deviceName}-system";
                  value = config.system.build.toplevel;
                }
              ]
            ) deviceNames)
          )
        );

      # Build nixosConfigurations from aarch64-linux build system
      # (Keep existing behavior for nixosConfigurations)
      defaultSystem = "aarch64-linux";
      
      devicesDir = ./devices;
      deviceNames = builtins.filter
        (name: name != "families" && builtins.pathExists (devicesDir + "/${name}/default.nix"))
        (builtins.attrNames (builtins.readDir devicesDir));

      microhopOverlay = final: prev: {
        microhop = microhop.packages.${defaultSystem}.microhop or (throw "microhop package not found in microhop flake");
        microgen = microhop.packages.${defaultSystem}.microgen or (throw "microgen package not found in microhop flake");
      };

      overlays = [
        microhopOverlay
        (import ./overlay/overlay.nix)
      ];

      buildDevice = deviceName:
        nixpkgs.lib.nixosSystem {
          system = defaultSystem;
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
