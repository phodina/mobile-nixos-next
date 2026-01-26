{
  description = "Mobile NixOS - NixOS on mobile devices";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };
      
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
            }
          ];
        };
      
      devices = builtins.listToAttrs (map (name: {
        name = name;
        value = buildDevice name;
      }) deviceNames);
      
    in {
      nixosConfigurations = devices;
      
      packages.${system} = builtins.listToAttrs (
        pkgs.lib.flatten (map (deviceName:
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
      );
    };
}
