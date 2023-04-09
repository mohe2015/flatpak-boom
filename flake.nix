{
  # nix repl
  # :lf .#
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
        #system = "x86_64-linux";
        imports = [
          pkgs.pkgsModule
          (nixpkgs + "/nixos/modules/system/etc/etc.nix")
          (nixpkgs + "/nixos/modules/misc/assertions.nix")
          (nixpkgs + "/nixos/modules/config/system-path.nix")
          (nixpkgs + "/nixos/modules/config/fonts/fonts.nix")
          (nixpkgs + "/nixos/modules/config/fonts/fontconfig.nix")
          ({ ... }: {
            fonts.fontconfig.ultimate.preset = false;
          })
        ];
      });
    in pkgs.runCommand "firefox" {} ''
      mkdir -p $out
      xargs tar c < ${pkgs.writeReferencesToFile inner} | tar -xC $out
      mkdir -p $out/
      cp -r ${nixosCore.config.system.build.etc}/etc $out
      mkdir -p $out/bin
      echo "${inner}/bin/firefox" >> $out/bin/firefox
    '';
  };
}
