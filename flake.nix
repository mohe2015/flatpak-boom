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
      runtime=org.mydomain.BasePlatform/x86_64/master
      sdk=org.mydomain.BaseSdk/x86_64/master
      EOF
      mkdir -p $out/files
      mkdir -p $out/usr
      ${pkgs.flatpak}/bin/flatpak build-finish $out
    '';

    packages.x86_64-linux.flatpak-sdk-empty = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in pkgs.runCommand "firefox" {} ''
      mkdir -p $out
      cat > $out/metadata << EOF
      [Runtime]
      name=org.mydomain.BaseSdk
      runtime=org.mydomain.BasePlatform/x86_64/master
      sdk=org.mydomain.BaseSdk/x86_64/master
      EOF
      mkdir -p $out/files/x86_64-unknown-linux-gnu/
      mkdir -p $out/usr
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
    flatpak-package = pkgs.runCommand "firefox" {} ''
      mkdir -p $out
      cat > $out/metadata << EOF
      [Application]
      name=org.mydomain.Firefox
      runtime=org.mydomain.BasePlatform/x86_64/master
      sdk=org.mydomain.BaseSdk/x86_64/master
      command=internal-run.sh
      EOF
      mkdir -p $out/files
      # TODO FIXME autodetect dependencies
      xargs tar c < ${pkgs.writeReferencesToFile (pkgs.linkFarmFromDrvs "myexample" [ inner pkgs.pkgsStatic.bash pkgs.pkgsStatic.coreutils pkgs.pkgsStatic.strace pkgs.pkgsStatic.gdb  nixosCore.config.system.build.etc ])} | tar -xC $out/files
      mkdir -p $out/
      cp -r ${nixosCore.config.system.build.etc}/etc $out/files
      mkdir -p $out/files/bin
      cat > $out/files/bin/internal-run.sh << EOF
      #!/app${pkgs.pkgsStatic.bash}/bin/bash
      set -ex
      echo "Hello world, from a sandbox"
      /app${pkgs.pkgsStatic.coreutils}/bin/ln -s /app/nix /nix
      ${pkgs.pkgsStatic.coreutils}/bin/ln -s /app/run/current-system /run/current-system
      ${pkgs.pkgsStatic.coreutils}/bin/cp -r --no-clobber ${nixosCore.config.system.build.etc}/etc/* /etc/
      ${pkgs.pkgsStatic.coreutils}/bin/ls -la /etc/
      ${inner}/bin/firefox
      EOF
      ls -la $out/files/bin/
      chmod +x $out/files/bin/internal-run.sh
      # TODO FIXME wayland only doesn't work yet
      ${pkgs.flatpak}/bin/flatpak build-finish --share=ipc --share=network --socket=cups --socket=pcsc --socket=pulseaudio --socket=wayland --socket=x11 --device=all --filesystem=xdg-download --talk-name=org.a11y.Bus --talk-name=org.freedesktop.FileManager1 --talk-name=org.freedesktop.Notifications --talk-name=org.freedesktop.ScreenSaver --talk-name=org.gnome.SessionManager --talk-name=org.gtk.vfs.* --own-name=org.mozilla.firefox.* --own-name=org.mozilla.firefox_beta.* --own-name=org.mpris.MediaPlayer2.firefox.* --system-talk-name=org.freedesktop.NetworkManager $out
       '';
  in pkgs.runCommand "firefox" {} ''
    mkdir -p $out/flatpak
    export TMP_REPO=$(mktemp -d)
    export XDG_DATA_HOME=$out
    ${pkgs.ostree}/bin/ostree init --mode bare-user-only --repo=$TMP_REPO
    ${pkgs.flatpak}/bin/flatpak build-export $TMP_REPO ${flatpak-package}
    ${pkgs.flatpak}/bin/flatpak build-export $TMP_REPO ${self.packages.x86_64-linux.flatpak-runtime-empty}
    ${pkgs.flatpak}/bin/flatpak build-export $TMP_REPO ${self.packages.x86_64-linux.flatpak-sdk-empty}
    ${pkgs.flatpak}/bin/flatpak --no-gpg-verify --user remote-add nix file://$TMP_REPO
    ${pkgs.flatpak}/bin/flatpak install --assumeyes --user --include-sdk nix org.mydomain.Firefox
    mkdir -p $out/bin
    echo "${pkgs.bubblewrap}/bin/bwrap --dev-bind / / --ro-bind $out/flatpak \\$HOME/.local/share/flatpak -- ${pkgs.flatpak}/bin/flatpak --user run org.mydomain.Firefox" > $out/bin/firefox
    chmod +x $out/bin/firefox
  '';
  };
  # nix run .#packages.x86_64-linux.firefox-flatpak
  # /nix/store/fann10rkra84rw3q3higd9wsxjn6pkij-bubblewrap-0.8.0/bin/bwrap --dev-bind / / --ro-bind ./result/flatpak $HOME/.local/share/flatpak -- /nix/store/p7g1m4d6vazqkarhlrrwakhbmpff0by8-flatpak-1.14.2/bin/flatpak --user run --devel --command=/app/nix/store/j44km7lwsc8s5dlvbm6d55v667k3a12d-strace-static-x86_64-unknown-linux-musl-6.2/bin/strace org.mydomain.Firefox -f internal-run.sh
}
