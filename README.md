```bash
# https://wiki.archlinux.org/title/Flatpak#Creating_a_custom_base_runtime
nix shell nixpkgs#ostree

mkdir myflatpakbuilddir
cd myflatpakbuilddir

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

mkdir -p myruntime/usr
mkdir -p mysdk/usr

ostree init --mode archive-z2 --repo=.

flatpak build-export . mysdk

flatpak build-export . myruntime

ostree summary -u

flatpak remote-add --user --no-gpg-verify myos file://$(pwd)

flatpak install --user myos org.mydomain.BasePlatform 2023-04-08
flatpak install --user myos org.mydomain.BaseSdk 2023-04-08

```