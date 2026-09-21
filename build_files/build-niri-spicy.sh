#!/usr/bin/bash
# Build losnoco's spicy niri fork and package it as an RPM.
# Runs in its own stage on the same base as the final image so rpmbuild's
# soname deps match what ships. Only /rpms escapes.
set -xeuo pipefail

NIRI_REPO="https://github.com/losnoco/niri.git"
NIRI_BRANCH="spicy-main"
SMITHAY_REPO="https://github.com/losnoco/smithay.git"
SMITHAY_BRANCH="spicy-master"

SRC="/usr/src/niri-spicy"
SPEC="$(dirname "$(readlink -f "$0")")/niri-spicy.spec"

# On /var/cache: out of the image layer, reused by local `just build`.
export CARGO_TARGET_DIR="/var/cache/niri-spicy-target"

### DEPENDENCIES
# From spicy's ci.yml DEPS_DNF. Fedora spells two differently: libgbm-devel is
# mesa-libgbm-devel, libudev-devel lives in systemd-devel.
# terra-mesa is mandatory. Bazzite excludes mesa-* from the Fedora repos and
# ships Terra's mesa at Epoch 1, which Fedora's epoch-0 -devel can't satisfy.
dnf5 install -y --enablerepo=terra-mesa \
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

### SOURCES
# spicy-main patches smithay to `path = "../smithay"`, so the two checkouts
# must be siblings.
mkdir -p "$SRC"
git clone --depth 1 --branch "$SMITHAY_BRANCH" "$SMITHAY_REPO" "$SRC/smithay"
git clone --depth 1 --branch "$NIRI_BRANCH" "$NIRI_REPO" "$SRC/niri"

NIRI_COMMIT="$(git -C "$SRC/niri" rev-parse --short HEAD)"
SMITHAY_COMMIT="$(git -C "$SRC/smithay" rev-parse --short HEAD)"
# First `version =` is [workspace.package].
NIRI_VERSION="$(grep -m1 '^version = ' "$SRC/niri/Cargo.toml" | cut -d'"' -f2)"
NIRI_RELEASE="1.spicy.$(date -u +%Y%m%d).git${NIRI_COMMIT}$(rpm -E '%{?dist}')"

### BUILD
# Otherwise niri shells out to `git describe`, which has nothing to say in a
# shallow clone.
export NIRI_BUILD_COMMIT="$NIRI_COMMIT"

# shaderc-sys (pulled in by smithay's renderer_vulkan) probes pkg-config for
# "shaderc", else builds bundled glslang with cmake. It links
# libshaderc_shared, so the RPM gets a soname dep dnf resolves downstream.
SHADERC_LIB_DIR="$(rpm -E '%{_libdir}')"
export SHADERC_LIB_DIR
test -f "$SHADERC_LIB_DIR/libshaderc_shared.so"

cd "$SRC/niri"
cargo build --release --locked

# Same completion set the Copr package ships.
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

### VERIFY
# An unresolved macro doesn't fail rpmbuild, it packages a directory literally
# named "%{_licensedir}". Check the payload, not the macros.
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
