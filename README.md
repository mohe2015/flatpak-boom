```bash
# https://wiki.archlinux.org/title/Flatpak#Creating_a_custom_base_runtime
# man flatpak-manifest
# https://github.com/flatpak/flatpak-builder/blob/main/data/flatpak-manifest.schema.json
# "$schema": "https://raw.githubusercontent.com/flatpak/flatpak-builder/main/data/flatpak-manifest.schema.json"
nix shell nixpkgs#ostree

mkdir myflatpakbuilddir
cd myflatpakbuilddir

ostree init --mode archive-z2 --repo=.

mkdir -p myruntime
mkdir -p mysdk

cat > myruntime/metadata << EOF
[Runtime]
name=org.mydomain.BasePlatform
runtime=org.mydomain.BasePlatform/x86_64/2023-04-08
sdk=org.mydomain.BaseSdk/x86_64/x86_64/2023-04-08
EOF

cat > mysdk/metadata << EOF
[Runtime]
name=org.mydomain.BaseSdk
runtime=org.mydomain.BasePlatform/x86_64/x86_64/2023-04-08
sdk=org.mydomain.BaseSdk/x86_64/x86_64/2023-04-08
EOF

mkdir -p myruntime/files
mkdir -p myruntime/usr
mkdir -p mysdk/files/x86_64-unknown-linux-gnu/
mkdir -p mysdk/usr

flatpak build-finish myruntime

flatpak build-export . mysdk

flatpak build-export . myruntime

ostree summary -u

flatpak remote-add --user --no-gpg-verify myos file://$(pwd)

flatpak install --user myos org.mydomain.BasePlatform 2023-04-08
flatpak install --user myos org.mydomain.BaseSdk 2023-04-08

```