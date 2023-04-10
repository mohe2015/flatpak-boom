{
  # nix repl
  # :lf .#
  description = "A very basic flake";

  outputs = { self, nixpkgs }: let
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
            time.timeZone = "Europe/Berlin";
            system.stateVersion = "23.05";
          })
        ];
      };
    # copied from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/hardware/opengl.nix
    cfg = nixosCore.config.hardware.opengl;
    package = pkgs.buildEnv {
      name = "opengl-drivers";
      paths = [ cfg.package ] ++ cfg.extraPackages;
    };
    package32 = pkgs.buildEnv {
      name = "opengl-drivers-32bit";
      paths = [ cfg.package32 ] ++ cfg.extraPackages32;
    }; in {

    packages.x86_64-linux.flatpak-runtime-base = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in pkgs.runCommand "flatpak-runtime-base" {} ''
      mkdir -p $out
      cat > $out/metadata << EOF
      [Runtime]
      name=org.mydomain.BasePlatform
      runtime=org.mydomain.BasePlatform/x86_64/master
      sdk=org.mydomain.BaseSdk/x86_64/master
      EOF
      mkdir -p $out/usr
      mkdir -p $out/files
      cp ${pkgs.writeReferencesToFile (pkgs.linkFarmFromDrvs "myexample" [ package package32 pkgs.glibcLocales pkgs.pkgsStatic.bash pkgs.pkgsStatic.coreutils pkgs.pkgsStatic.strace pkgs.pkgsStatic.gdb nixosCore.config.system.build.etc ])} $out/references
      xargs tar c < $out/references | tar -xC $out/usr
      ls -la $out/usr
      ${pkgs.flatpak}/bin/flatpak build-finish $out
    '';

    packages.x86_64-linux.flatpak-sdk-base = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in pkgs.runCommand "flatpak-sdk-base" {} ''
      mkdir -p $out
      cat > $out/metadata << EOF
      [Runtime]
      name=org.mydomain.BaseSdk
      runtime=org.mydomain.BasePlatform/x86_64/master
      sdk=org.mydomain.BaseSdk/x86_64/master
      EOF
      mkdir -p $out/usr
      mkdir -p $out/files/x86_64-unknown-linux-gnu/
      ${pkgs.flatpak}/bin/flatpak build-finish $out
    '';

    packages.x86_64-linux.firefox-flatpak = let
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
      cp ${pkgs.writeReferencesToFile (pkgs.linkFarmFromDrvs "myexample" [ inner ])} references
      grep -v -x -F -f ${self.packages.x86_64-linux.flatpak-runtime-base}/references references > $out/references
      xargs tar c < $out/references | tar -xC $out/files # TODO FIXME filter out dependencies already contained in base
      mkdir -p $out/
      mkdir -p $out/files/etc/firefox
      cp ${pkgs.firefox}/lib/firefox/mozilla.cfg $out/files/etc/firefox/mozilla.cfg
      cp -r ${nixosCore.config.system.build.etc}/etc $out/files
      mkdir -p $out/files/run/current-system/sw/lib/locale/
      cp ${pkgs.glibcLocales}/lib/locale/locale-archive $out/files/run/current-system/sw/lib/locale/locale-archive
      ln -s ${package} $out/files/run/opengl-driver
      ln -s ${package32} $out/files/run/opengl-driver-32
      mkdir -p $out/files/bin

      cat > $out/files/bin/internal-run.sh << EOF
      #!/app${pkgs.pkgsStatic.bash}/bin/bash
      set -ex
      echo "Hello world, from a sandbox"
      /app${pkgs.pkgsStatic.coreutils}/bin/ln -s /app/nix /nix
      ${pkgs.pkgsStatic.coreutils}/bin/ln -s /app/run/current-system /run/current-system
      ${pkgs.pkgsStatic.coreutils}/bin/ln -s /app/run/opengl-driver /run/opengl-driver
      ${pkgs.pkgsStatic.coreutils}/bin/ln -s /app/run/opengl-driver-32 /run/opengl-driver-32
      ${pkgs.pkgsStatic.coreutils}/bin/cp -r --no-clobber ${nixosCore.config.system.build.etc}/etc/* /etc/
      ${pkgs.pkgsStatic.coreutils}/bin/cp -r --no-clobber /app/etc/firefox /etc/
      ${pkgs.pkgsStatic.coreutils}/bin/ls -la /etc/
      ${pkgs.pkgsStatic.coreutils}/bin/ls -la /run/
      ${inner}/bin/firefox
      EOF

      ls -la $out/files/bin/
      chmod +x $out/files/bin/internal-run.sh
      # TODO FIXME wayland only doesn't work yet
      ${pkgs.flatpak}/bin/flatpak build-finish --share=ipc --share=network --socket=cups --socket=pcsc --socket=pulseaudio --socket=x11 --socket=wayland --device=all --filesystem=xdg-download --talk-name=org.a11y.Bus --talk-name=org.freedesktop.FileManager1 --talk-name=org.freedesktop.Notifications --talk-name=org.freedesktop.ScreenSaver --talk-name=org.gnome.SessionManager --talk-name=org.gtk.vfs.* --own-name=org.mozilla.firefox.* --own-name=org.mozilla.firefox_beta.* --own-name=org.mpris.MediaPlayer2.firefox.* --system-talk-name=org.freedesktop.NetworkManager $out
       '';
  in pkgs.runCommand "create-repo" {} ''
    mkdir -p $out/flatpak
    export TMP_REPO=$(mktemp -d)
    export XDG_DATA_HOME=$out
    ${pkgs.ostree}/bin/ostree init --mode bare-user-only --repo=$TMP_REPO
    ${pkgs.flatpak}/bin/flatpak build-export $TMP_REPO ${flatpak-package}
    ${pkgs.flatpak}/bin/flatpak build-export $TMP_REPO ${self.packages.x86_64-linux.flatpak-runtime-base}
    ${pkgs.flatpak}/bin/flatpak build-export $TMP_REPO ${self.packages.x86_64-linux.flatpak-sdk-base}
    ${pkgs.flatpak}/bin/flatpak --no-gpg-verify --user remote-add nix file://$TMP_REPO
    ${pkgs.flatpak}/bin/flatpak install --assumeyes --user --include-sdk nix org.mydomain.Firefox
    mkdir -p $out/bin
    echo "${pkgs.bubblewrap}/bin/bwrap --dev-bind / / --ro-bind $out/flatpak \$HOME/.local/share/flatpak -- ${pkgs.flatpak}/bin/flatpak --user run org.mydomain.Firefox" > $out/bin/firefox
    chmod +x $out/bin/firefox
  '';
  };
  # https://github.com/search?q=repo%3Aflatpak%2Fflatpak+.ref&type=code
  # nix run .#packages.x86_64-linux.firefox-flatpak
  # /nix/store/fann10rkra84rw3q3higd9wsxjn6pkij-bubblewrap-0.8.0/bin/bwrap --dev-bind / / --ro-bind ./result/flatpak $HOME/.local/share/flatpak -- /nix/store/p7g1m4d6vazqkarhlrrwakhbmpff0by8-flatpak-1.14.2/bin/flatpak --user run --devel --command=/app/nix/store/j44km7lwsc8s5dlvbm6d55v667k3a12d-strace-static-x86_64-unknown-linux-musl-6.2/bin/strace org.mydomain.Firefox -f internal-run.sh
  # clear && /nix/store/fann10rkra84rw3q3higd9wsxjn6pkij-bubblewrap-0.8.0/bin/bwrap --dev-bind / / --ro-bind ./result/flatpak $HOME/.local/share/flatpak -- /nix/store/p7g1m4d6vazqkarhlrrwakhbmpff0by8-flatpak-1.14.2/bin/flatpak --user run --devel --command=/app/nix/store/j44km7lwsc8s5dlvbm6d55v667k3a12d-strace-static-x86_64-unknown-linux-musl-6.2/bin/strace org.mydomain.Firefox -e 'trace=!futex,sched_yield,close,poll,munmap,gettid,mmap,fcntl,ftruncate,write,read,sendmsg,recvmsg,getrandom,sched_getaffinity,epoll_wait,mprotect,prctl,getpriority,sigaltstack,pread64,pwrite64,rt_sigaction,fallocate,getpid,madvise,rt_sigprocmask,set_robust_list,rseq,clone3,seccomp,dup,fsync,pipe2,eventfd2,getcwd,prlimit64,getuid,geteuid,getgid,getegid,epoll_ctl,setpriority,clone,exit,set_tid_address,brk,getppid,arch_prctl,writev,readv,lseek,socketpair,dup2,fstat,wait4,ioctl,getdents64,exit_group,socket,copy_file_range' -f internal-run.sh 2>&1 | grep -v /nix/store
  # /nix/store/fann10rkra84rw3q3higd9wsxjn6pkij-bubblewrap-0.8.0/bin/bwrap --dev-bind / / --ro-bind ./result/flatpak $HOME/.local/share/flatpak -- /nix/store/p7g1m4d6vazqkarhlrrwakhbmpff0by8-flatpak-1.14.2/bin/flatpak --user run --devel --command=/app/nix/store/fj45303ravmhqnj4f1jlsxan8rb03qv9-gdb-static-x86_64-unknown-linux-musl-13.1/bin/gdb org.mydomain.Firefox /app/nix/store/6c1pxa6x6mb6z0g6ga1n00mjv43x9mf9-bash-5.2-p15-x86_64-unknown-linux-musl/bin/bash --args internal-run.sh
  /*
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install org.freedesktop.Platform
flatpak install org.freedesktop.Sdk
flatpak build-init --type=runtime test a.b.c org.freedesktop.Sdk org.freedesktop.Platform

1.     org.mydomain.BasePlatform   master   i    nix     < 3.2?GB
firefox>  2.     org.mydomain.BaseSdk        master   i    nix     < 123 bytes
firefox>  3.     org.mydomain.Firefox        master   i    nix     < 1.3?GB
  */
}

