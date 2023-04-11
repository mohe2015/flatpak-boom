{
  # nix repl
  # :lf .#
  description = "A very basic flake";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      inner = pkgs.firefox;
      nixosLib = import (nixpkgs + "/nixos/lib") {
      };
      nixosCore = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ ... }: {
            environment.enableDebugInfo = true;
            time.timeZone = "Europe/Berlin";
            # TODO FIXME more from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/i18n.nix
            # honor systemd.globalEnvironment and environment.sessionVariables?
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
      };
      drv2flatpak = drv: pkgs.runCommand "create-repo" { } ''
        mkdir -p $out
        ${pkgs.ostree}/bin/ostree init --mode bare-user-only --repo=$out
        ${pkgs.flatpak}/bin/flatpak build-export $out ${drv}
      '';
      buildRuntimeOrSdk = name: (pkgs.runCommand "flatpak-${name}-base" { } ''
          mkdir -p $out
          cat > $out/metadata << EOF
          [Runtime]
          name=org.mydomain.${name}
          runtime=org.mydomain.BasePlatform/x86_64/master
          sdk=org.mydomain.BaseSdk/x86_64/master
          EOF
          mkdir -p $out/usr
          mkdir -p $out/files
          cp ${pkgs.writeReferencesToFile (pkgs.linkFarmFromDrvs "myexample" ([ package package32 pkgs.glibcLocales pkgs.pkgsStatic.bash pkgs.pkgsStatic.coreutils pkgs.strace pkgs.gdb nixosCore.config.system.build.etc ] ++ nixosCore.config.environment.systemPackages) )} $out/files/references
          xargs tar c < $out/files/references | tar -xC $out/usr
          ls -la $out/usr
          ${pkgs.flatpak}/bin/flatpak build-finish $out
        '');
    in
    {

      packages.x86_64-linux.runtime-base = buildRuntimeOrSdk "BasePlatform";

      packages.x86_64-linux.flatpak-runtime-base = drv2flatpak self.packages.x86_64-linux.runtime-base;

      # TODO FIXME don't make this rebuild
      packages.x86_64-linux.sdk-base = buildRuntimeOrSdk "BaseSdk";

      packages.x86_64-linux.flatpak-sdk-base = drv2flatpak self.packages.x86_64-linux.sdk-base;

      packages.x86_64-linux.firefox = (pkgs.runCommand "firefox" { } ''
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
        cp ${pkgs.writeReferencesToFile (pkgs.linkFarmFromDrvs "myexample" [ inner pkgs.glibc.bin ])} references
        grep -v -x -F -f ${self.packages.x86_64-linux.runtime-base}/files/references references > $out/files/references
        xargs tar c < $out/files/references | tar -xC $out/files # TODO FIXME filter out dependencies already contained in base
        mkdir -p $out/
        mkdir -p $out/files/etc/firefox
        cp ${pkgs.firefox}/lib/firefox/mozilla.cfg $out/files/etc/firefox/mozilla.cfg
        cp -r ${nixosCore.config.system.build.etc}/etc $out/files
        mkdir -p $out/files/run/current-system/sw/lib/locale/
        cp -r ${nixosCore.config.system.path}/ $out/files/run/current-system/sw/
        ln -s ${package} $out/files/run/opengl-driver
        ln -s ${package32} $out/files/run/opengl-driver-32
        mkdir -p $out/files/bin
        ln -s ${pkgs.pkgsStatic.bash}/bin/sh $out/files/bin/sh
        cat > $out/files/bin/internal-run.sh << EOF
        #!/usr${pkgs.pkgsStatic.bash}/bin/bash
        set -ex
        echo "Hello world, from a sandbox"
        /usr${pkgs.pkgsStatic.coreutils}/bin/mkdir -p /nix/store
        /usr${pkgs.pkgsStatic.coreutils}/bin/mkdir -p /bin
        /usr${pkgs.pkgsStatic.coreutils}/bin/ln -s /usr/nix/store/* /nix/store/
        /usr${pkgs.pkgsStatic.coreutils}/bin/ln -s /app/nix/store/* /nix/store/
        ${pkgs.pkgsStatic.coreutils}/bin/ls -la /app/run/
        ${pkgs.pkgsStatic.coreutils}/bin/ln -s /app/run/* /run/
        ${pkgs.pkgsStatic.coreutils}/bin/ln -s /app/bin/* /bin/
        ${pkgs.pkgsStatic.coreutils}/bin/cp -r --no-clobber ${nixosCore.config.system.build.etc}/etc/* /etc/
        ${pkgs.pkgsStatic.coreutils}/bin/cp -r --no-clobber /app/etc/firefox /etc/
        ${pkgs.pkgsStatic.coreutils}/bin/ls -la /etc/
        ${pkgs.pkgsStatic.coreutils}/bin/ls -la /run/current-system/sw
        #${pkgs.glibc.bin}/bin/ldd ${inner}/bin/.firefox-wrapped
        # ${pkgs.strace}/bin/strace -f
        ${nixpkgs.lib.concatStringsSep "\n" (nixpkgs.lib.mapAttrsToList (key: value: "export " + key + "=\"" + value + "\"") nixosCore.config.environment.variables)}
        ${pkgs.gdb}/bin/gdb --eval-command="set debuginfod enabled on" --eval-command="set detach-on-fork off" --eval-command="set auto-load safe-path /" --eval-command=run -q --args ${pkgs.pkgsStatic.bash}/bin/bash ${inner}/bin/firefox --g-fatal-warnings
        EOF

        ls -la $out/files/bin/
        chmod +x $out/files/bin/internal-run.sh
        # TODO FIXME wayland only doesn't work yet
        ${pkgs.flatpak}/bin/flatpak build-finish --share=ipc --share=network --socket=cups --socket=pcsc --socket=pulseaudio --socket=wayland --device=all --filesystem=xdg-download --talk-name=org.a11y.Bus --talk-name=org.freedesktop.FileManager1 --talk-name=org.freedesktop.Notifications --talk-name=org.freedesktop.ScreenSaver --talk-name=org.gnome.SessionManager --talk-name=org.gtk.vfs.* --own-name=org.mozilla.firefox.* --own-name=org.mozilla.firefox_beta.* --own-name=org.mpris.MediaPlayer2.firefox.* --system-talk-name=org.freedesktop.NetworkManager $out
      '');

      packages.x86_64-linux.flatpak-firefox = drv2flatpak self.packages.x86_64-linux.firefox;
    };
  /*
    nix build -L .#flatpak-firefox && flatpak install --or-update --assumeyes --user --include-sdk nix org.mydomain.Firefox && flatpak run --devel org.mydomain.Firefox

    flatpak --no-gpg-verify --user remote-add nix file://$PWD/result
    nix build -L .#flatpak-runtime-base
    flatpak install --or-update --assumeyes --user org.mydomain.BasePlatform
    nix build -L .#flatpak-sdk-base
    flatpak install --or-update --assumeyes --user org.mydomain.BaseSdk
    nix build -L .#flatpak-firefox
    flatpak install --or-update --assumeyes --user --include-sdk nix org.mydomain.Firefox
    flatpak run --devel org.mydomain.Firefox
    fg # get process again
  */

  # clear && /nix/store/fann10rkra84rw3q3higd9wsxjn6pkij-bubblewrap-0.8.0/bin/bwrap --dev-bind / / --ro-bind ./result/flatpak $HOME/.local/share/flatpak -- /nix/store/p7g1m4d6vazqkarhlrrwakhbmpff0by8-flatpak-1.14.2/bin/flatpak --user run --devel --command=/app/nix/store/j44km7lwsc8s5dlvbm6d55v667k3a12d-strace-static-x86_64-unknown-linux-musl-6.2/bin/strace org.mydomain.Firefox -e 'trace=!futex,sched_yield,close,poll,munmap,gettid,mmap,fcntl,ftruncate,write,read,sendmsg,recvmsg,getrandom,sched_getaffinity,epoll_wait,mprotect,prctl,getpriority,sigaltstack,pread64,pwrite64,rt_sigaction,fallocate,getpid,madvise,rt_sigprocmask,set_robust_list,rseq,clone3,seccomp,dup,fsync,pipe2,eventfd2,getcwd,prlimit64,getuid,geteuid,getgid,getegid,epoll_ctl,setpriority,clone,exit,set_tid_address,brk,getppid,arch_prctl,writev,readv,lseek,socketpair,dup2,fstat,wait4,ioctl,getdents64,exit_group,socket,copy_file_range' -f internal-run.sh 2>&1 | grep -v /nix/store
}

