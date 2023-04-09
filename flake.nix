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
      # nixosLib.evalModules;
      nixosCore = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          #pkgs.pkgsModule
          #(nixpkgs + "/nixos/modules/system/etc/etc.nix")
          #(nixpkgs + "/nixos/modules/misc/assertions.nix")
          #(nixpkgs + "/nixos/modules/config/system-path.nix")
          #(nixpkgs + "/nixos/modules/config/fonts/fonts.nix")
          #(nixpkgs + "/nixos/modules/config/fonts/fontconfig.nix")
          ({ ... }: {
            system.stateVersion = "23.05";
          })
        ];
      };
      # https://github.com/yawnt/declarative-nix-flatpak/blob/a82b3b135f79b78c379c4f1b0c52957cd7ccf50c/flatpak.nix#L4-L12
      script = name: app: runtime: pkgs.writeScriptBin "${name}" ''
    FLATPAK_DIR=$HOME/.local/share/flatpak
    ${pkgs.bubblewrap}/bin/bwrap \
      --dev-bind / / \
      --tmpfs $FLATPAK_DIR \
      --ro-bind ${app} $FLATPAK_DIR/app \
      --ro-bind ${runtime} $FLATPAK_DIR/runtime \
      ${pkgs.flatpak}/bin/flatpak --user run ${name}
  '';
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
