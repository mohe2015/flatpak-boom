```bash
# https://wiki.archlinux.org/title/Flatpak#Creating_a_custom_base_runtime
nix shell nixpkgs#ostree

mkdir myflatpakbuilddir
cd myflatpakbuilddir

ostree init --mode bare-user --repo=.

mkdir -p myruntime
mkdir -p mysdk

cat > myruntime/metadata << EOF
[Runtime]
name=org.mydomain.BasePlatform
runtime=org.mydomain.BasePlatform/x86_64/2023-04-08
sdk=org.mydomain.BaseSdk/x86_64/2023-04-08
EOF

cat > mysdk/metadata << EOF
[Runtime]
name=org.mydomain.BaseSdk
runtime=org.mydomain.BasePlatform/x86_64/2023-04-08
sdk=org.mydomain.BaseSdk/x86_64/2023-04-08
EOF

mkdir -p myruntime/files
mkdir -p myruntime/usr
mkdir -p mysdk/files/x86_64-unknown-linux-gnu/
mkdir -p mysdk/usr

flatpak build-export . mysdk

flatpak build-export . myruntime

flatpak remote-add --user --no-gpg-verify myos file://$(pwd)

flatpak remote-ls myos

flatpak install --user myos org.mydomain.BasePlatform
flatpak install --user myos org.mydomain.BaseSdk

mkdir -p /tmp/kate/files/bin

# TODO REPLACE with build-finish which you can pass permissions https://wiki.archlinux.org/title/Flatpak#Creating_a_custom_base_runtime
cat > /tmp/kate/metadata << EOF
[Application]
name=org.mydomain.Kate
runtime=org.mydomain.BasePlatform/x86_64/master
sdk=org.mydomain.BaseSdk/x86_64/master
command=run.sh

[Context]
sockets=wayland;
EOF

cat > /tmp/kate/files/bin/run.sh << EOF
#!/app/nix/store/6c1pxa6x6mb6z0g6ga1n00mjv43x9mf9-bash-5.2-p15-x86_64-unknown-linux-musl/bin/bash
echo "Hello world, from a sandbox"
/app/nix/store/gkfxaxd7qhd55nc8lyxgr0834548fdbg-coreutils-static-x86_64-unknown-linux-musl-9.1/bin/ln -s /app/nix /nix
/nix/store/q9s42y6c544qngvr76l3p1rwv303hpq5-kate-22.12.3/bin/kate
EOF
chmod +x /tmp/kate/files/bin/run.sh

mkdir -p /tmp/kate/files/nix

nix shell nixpkgs#kate nixpkgs#pkgsStatic.bash nixpkgs#pkgsStatic.coreutils

nix copy --to /tmp/kate/files nixpkgs#kate --no-check-sigs
nix copy --to /tmp/kate/files nixpkgs#pkgsStatic.bash --no-check-sigs
nix copy --to /tmp/kate/files nixpkgs#pkgsStatic.coreutils --no-check-sigs
chmod -R 755 /tmp/kate/files/nix

flatpak build-finish /tmp/kate
flatpak build-export . /tmp/kate

flatpak remote-ls myos

flatpak install --or-update --user myos org.mydomain.Kate
flatpak run org.mydomain.Kate

# firefox
flatpak build-init /tmp/firefox org.mydomain.Firefox org.mydomain.BaseSdk/x86_64/master org.mydomain.BasePlatform/x86_64/master
mkdir -p /tmp/firefox/files/bin
mkdir -p /tmp/firefox/files/share
cat > /tmp/firefox/files/bin/run.sh << EOF
#!/app/nix/store/6c1pxa6x6mb6z0g6ga1n00mjv43x9mf9-bash-5.2-p15-x86_64-unknown-linux-musl/bin/bash
set -ex
echo "Hello world, from a sandbox"
/app/nix/store/gkfxaxd7qhd55nc8lyxgr0834548fdbg-coreutils-static-x86_64-unknown-linux-musl-9.1/bin/ln -s /app/nix /nix
/app/nix/store/gkfxaxd7qhd55nc8lyxgr0834548fdbg-coreutils-static-x86_64-unknown-linux-musl-9.1/bin/ln -s /app/etc/localtime /etc/localtime
/app/nix/store/gkfxaxd7qhd55nc8lyxgr0834548fdbg-coreutils-static-x86_64-unknown-linux-musl-9.1/bin/ln -s /app/run/current-system /run/current-system
/nix/store/gkfxaxd7qhd55nc8lyxgr0834548fdbg-coreutils-static-x86_64-unknown-linux-musl-9.1/bin/ls -la /
/nix/store/gkfxaxd7qhd55nc8lyxgr0834548fdbg-coreutils-static-x86_64-unknown-linux-musl-9.1/bin/ls -la /run
/nix/store/dvnrfhs6sm1jhy2kmnrwxczgq6xchrk0-firefox-111.0.1/bin/firefox
EOF
chmod +x /tmp/firefox/files/bin/run.sh
mkdir -p /tmp/firefox/files/etc/
cp /etc/localtime /tmp/firefox/files/etc/localtime
mkdir -p /tmp/firefox/files/run/current-system/sw/lib/locale/
cp /run/current-system/sw/lib/locale/locale-archive /tmp/firefox/files/run/current-system/sw/lib/locale/locale-archive
nix copy --to /tmp/firefox/files nixpkgs#firefox --no-check-sigs
nix copy --to /tmp/firefox/files nixpkgs#pkgsStatic.bash --no-check-sigs
nix copy --to /tmp/firefox/files nixpkgs#pkgsStatic.coreutils --no-check-sigs
nix copy --to /tmp/firefox/files nixpkgs#pkgsStatic.strace --no-check-sigs

rmdir /tmp/firefox/export/
flatpak build-finish --command=run.sh --share=ipc --share=network --socket=cups --socket=pcsc --socket=pulseaudio --socket=wayland --socket=x11 --device=all --filesystem=xdg-download --talk-name=org.a11y.Bus --talk-name=org.freedesktop.FileManager1 --talk-name=org.freedesktop.Notifications --talk-name=org.freedesktop.ScreenSaver --talk-name=org.gnome.SessionManager --talk-name=org.gtk.vfs.* --own-name=org.mozilla.firefox.* --own-name=org.mozilla.firefox_beta.* --own-name=org.mpris.MediaPlayer2.firefox.* --system-talk-name=org.freedesktop.NetworkManager /tmp/firefox
flatpak build-export --ostree-verbose --disable-fsync . /tmp/firefox

org.mozilla.firefox permissions:
    ipc                     network                      cups       pcsc       pulseaudio       wayland       x11       devices       file access [1]      dbus access [2]
    bus ownership [3]       system dbus access [4]

    [1] xdg-download
    [2] org.a11y.Bus, org.freedesktop.FileManager1, org.freedesktop.Notifications, org.freedesktop.ScreenSaver, org.gnome.SessionManager, org.gtk.vfs.*
    [3] org.mozilla.firefox.*, org.mozilla.firefox_beta.*, org.mpris.MediaPlayer2.firefox.*
    [4] org.freedesktop.NetworkManager

flatpak install --or-update --user myos org.mydomain.Firefox
flatpak run org.mydomain.Firefox
flatpak run --devel --command=/app/nix/store/j44km7lwsc8s5dlvbm6d55v667k3a12d-strace-static-x86_64-unknown-linux-musl-6.2/bin/strace org.mydomain.Firefox -f run.sh 2>&1 | grep --color font
flatpak run --devel --command=/app/nix/store/j44km7lwsc8s5dlvbm6d55v667k3a12d-strace-static-x86_64-unknown-linux-musl-6.2/bin/strace org.mydomain.Firefox -f run.sh 2>&1 | grep -v /nix/store

# maybe copy permissions of official flatpak
# /etc/ld-nix.so.preload
# /run/current-system/sw/lib/locale/locale-archive
#/etc/nsswitch.conf
# /etc/resolv.conf
# /run/dbus/system_bus_socket

```