{
  description = "A very basic flake";

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.firefox-flatpak = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      inner = pkgs.firefox;
      nixosLib = import (nixpkgs + "/nixos/lib") {
        # Experimental features need testing too, but there's no point in warning
        # about it, so we enable the feature flag.
        featureFlags.minimalModules = {};
      };
      evalMinimalConfig = module: nixosLib.evalModules { modules = [ module ]; };
      nixosCore = evalMinimalConfig ({ config, ... }: {
        system = "x86_64-linux";
        imports = [
          (nixpkgs + "/nixos/modules/system/etc/etc.nix")
          ({ ... }: {
            system.stateVersion = "23.05";
          })
        ];
      });
    in pkgs.runCommand "firefox" {} ''
      set -x
      echo ${pkgs.writeReferencesToFile inner}
      mkdir -p /etc
      ${nixosCore.config.system.build.etcActivationCommands}
      mv /etc $out/etc
      echo "${inner}/bin/firefox" >> $out/bin/firefox
    '';
  };
}
