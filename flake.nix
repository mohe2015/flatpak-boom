{
  # nix repl
  # :lf .#
  description = "A very basic flake";

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.flatpak-runtime-empty = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in pkgs.runCommand "firefox" {} ''
      mkdir -p $out
      cat > $out/metadata << EOF
      [Runtime]
      name=org.mydomain.BasePlatform
      runtime=org.mydomain.BasePlatform/x86_64/2023-04-08
      sdk=org.mydomain.BaseSdk/x86_64/2023-04-08
      EOF
      mkdir -p $out/files
      ${pkgs.flatpak}/bin/flatpak build-finish $out
    '';

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
      script = name: app: runtime-name: runtime: ''
    FLATPAK_DIR=$HOME/.local/share/flatpak
    ${pkgs.bubblewrap}/bin/bwrap \
      --dev-bind / / \
      --tmpfs $FLATPAK_DIR \
      --ro-bind ${app} $FLATPAK_DIR/app/${name}/current/active \
      --ro-bind ${runtime} $FLATPAK_DIR/runtime/${runtime-name}/x86_64/stable/active \
      ls -la $FLATPAK_DIR
      #${pkgs.flatpak}/bin/flatpak --user run ${name}
  '';
    flatpak-package = pkgs.runCommand "firefox" {} ''
      mkdir -p $out
      ${pkgs.ostree}/bin/ostree init --mode bare-user-only --repo=.
      cat > $out/metadata << EOF
      [Application]
      name=org.mydomain.Firefox
      runtime=org.mydomain.BasePlatform/x86_64/master
      sdk=org.mydomain.BaseSdk/x86_64/master
      command=internal-run.sh
      EOF
      mkdir -p $out/files
      xargs tar c < ${pkgs.writeReferencesToFile inner} | tar -xC $out/files
      mkdir -p $out/
      cp -r ${nixosCore.config.system.build.etc}/etc $out/files
      mkdir -p $out/files/bin
      # TODO shebang
      echo "${inner}/bin/firefox" > $out/files/bin/internal-run.sh
      ${pkgs.flatpak}/bin/flatpak build-finish $out
       '';
  in pkgs.runCommand "firefox" {} ''
    mkdir -p $out/bin
    echo '${script "org.mydomain.Firefox" flatpak-package "org.mydomain.BasePlatform" self.packages.x86_64-linux.flatpak-runtime-empty}' > $out/bin/firefox
    chmod +x $out/bin/firefox
  '';
  };
}
