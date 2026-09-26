#!/usr/bin/bash
# Builds losnoco spicy niri fork as an RPM
set -xeuo pipefail

NIRI_REPO="https://github.com/losnoco/niri.git"
NIRI_BRANCH="spicy-main"
SMITHAY_REPO="https://github.com/losnoco/smithay.git"
SMITHAY_BRANCH="spicy-master"

SRC="/usr/src/niri-spicy"
SPEC="$(dirname "$(readlink -f "$0")")/niri-spicy.spec"

# build out of the image layer
export CARGO_TARGET_DIR="/var/cache/niri-spicy-target"
export CARGO_HOME="/var/cache/niri-spicy-cargo"

# deps from spicy's ci.yml DEPS_DNF
dnf5 install -y --nogpgcheck \
  --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
  terra-release terra-release-mesa
dnf5 install -y \
  cargo \
  clang-devel \
  gcc \
  git-core \
  rpm-build \
  cairo-gobject-devel \
  dbus-devel \
  libdisplay-info-devel \
  libinput-devel \
  libseat-devel \
  libshaderc-devel \
  libxkbcommon-devel \
  mesa-libgbm-devel \
  pango-devel \
  pipewire-devel \
  systemd-devel \
  wayland-devel

# spicy-main needs parallel clone of smithay
mkdir -p "$SRC"
git clone --depth 1 --branch "$SMITHAY_BRANCH" "$SMITHAY_REPO" "$SRC/smithay"
git clone --depth 1 --branch "$NIRI_BRANCH" "$NIRI_REPO" "$SRC/niri"

NIRI_COMMIT="$(git -C "$SRC/niri" rev-parse --short HEAD)"
SMITHAY_COMMIT="$(git -C "$SRC/smithay" rev-parse --short HEAD)"
# First `version =` is [workspace.package].
NIRI_VERSION="$(grep -m1 '^version = ' "$SRC/niri/Cargo.toml" | cut -d'"' -f2)"
NIRI_RELEASE="1.spicy.$(date -u +%Y%m%d).git${NIRI_COMMIT}$(rpm -E '%{?dist}')"

export NIRI_BUILD_COMMIT="$NIRI_COMMIT"

# link shaderc-sys
SHADERC_LIB_DIR="$(rpm -E '%{_libdir}')"
export SHADERC_LIB_DIR
test -f "$SHADERC_LIB_DIR/libshaderc_shared.so"

cd "$SRC/niri"
cargo build --release --locked

COMPDIR="$CARGO_TARGET_DIR/completions"
mkdir -p "$COMPDIR"
"$CARGO_TARGET_DIR/release/niri" completions bash >"$COMPDIR/niri"
"$CARGO_TARGET_DIR/release/niri" completions zsh >"$COMPDIR/_niri"
"$CARGO_TARGET_DIR/release/niri" completions fish >"$COMPDIR/niri.fish"

### PACKAGE
rpmbuild -bb \
  --define "_topdir $SRC/rpmbuild" \
  --define "%_tmppath %{_topdir}/tmp" \
  --define "niri_version $NIRI_VERSION" \
  --define "niri_release $NIRI_RELEASE" \
  --define "niri_srcdir $SRC/niri" \
  --define "niri_targetdir $CARGO_TARGET_DIR" \
  --define "niri_compdir $COMPDIR" \
  --define "niri_ref $NIRI_BRANCH@$NIRI_COMMIT" \
  --define "smithay_ref $SMITHAY_BRANCH@$SMITHAY_COMMIT" \
  "$SPEC"

mkdir -p /rpms
cp "$SRC"/rpmbuild/RPMS/*/niri-*.rpm /rpms/
ls -la /rpms

# verify
rpm -qlp /rpms/niri-*.rpm
for path in \
  /usr/bin/niri \
  /usr/bin/niri-session \
  /usr/lib/systemd/user/niri.service \
  /usr/lib/systemd/user/niri-shutdown.target \
  /usr/share/wayland-sessions/niri.desktop \
  /usr/share/xdg-desktop-portal/niri-portals.conf \
  /usr/share/bash-completion/completions/niri \
  /usr/share/zsh/site-functions/_niri \
  /usr/share/fish/vendor_completions.d/niri.fish \
  /usr/share/licenses/niri/LICENSE; do
  rpm -qlp /rpms/niri-*.rpm | grep -qxF "$path" || {
    echo "niri-spicy RPM is missing $path" >&2
    exit 1
  }
done
