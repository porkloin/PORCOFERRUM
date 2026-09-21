#!/usr/bin/env bash
# Build losnoco's "spicy" niri fork and package it as an RPM that drops in for the
# yalter/niri-git build bazzirco ships. Adds HDR, a Vulkan renderer, window
# minimizing and tearing control. There are no prebuilt RPMs for it anywhere, so
# we compile it ourselves.
#
# Runs in its own builder stage off the same base image as the final stage, so the
# soname and symbol-version deps rpmbuild generates match what the image actually
# ships. Only /rpms survives into the final image.
set -xeuo pipefail

NIRI_REPO="https://github.com/losnoco/niri.git"
NIRI_BRANCH="spicy-main"
SMITHAY_REPO="https://github.com/losnoco/smithay.git"
SMITHAY_BRANCH="spicy-master"

SRC="/usr/src/niri-spicy"

# Keep the target dir on the /var/cache mount so it stays out of the image layer
# and gets reused by `just build` locally.
export CARGO_TARGET_DIR="/var/cache/niri-spicy-target"

# Dep list comes from losnoco/niri .github/workflows/ci.yml (DEPS_DNF), with the
# two Fedora spellings: libgbm-devel -> mesa-libgbm-devel, and libudev-devel is
# folded into systemd-devel.
#
# terra-mesa has to be enabled for mesa-libgbm-devel. Bazzite excludes mesa-* from
# the Fedora repos and ships Terra's mesa instead, which carries Epoch 1 — so
# Fedora's epoch-0 -devel package can never satisfy its own versioned dep here.
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

# spicy-main's Cargo.toml carries
#   [patch."https://github.com/Smithay/smithay.git"] smithay = { path = "../smithay" }
# so the two checkouts have to be siblings or the build won't resolve.
mkdir -p "$SRC"
git clone --depth 1 --branch "$SMITHAY_BRANCH" "$SMITHAY_REPO" "$SRC/smithay"
git clone --depth 1 --branch "$NIRI_BRANCH" "$NIRI_REPO" "$SRC/niri"

cd "$SRC/niri"

niri_commit="$(git rev-parse --short HEAD)"
smithay_commit="$(git -C "$SRC/smithay" rev-parse --short HEAD)"
# [workspace.package] version, the first `version =` in the file.
niri_version="$(grep -m1 '^version = ' Cargo.toml | cut -d'"' -f2)"

# niri falls back to `git describe` for its version banner, which has nothing
# useful to say in a shallow clone. Hand it the commit directly instead.
export NIRI_BUILD_COMMIT="$niri_commit"

# smithay's renderer_vulkan feature pulls in shaderc-sys, which otherwise cannot
# find a system shaderc and falls back to building its bundled glslang/SPIRV-Tools
# with cmake. Point it at Fedora's shaderc instead. It links libshaderc_shared,
# so the RPM picks up a soname dep on libshaderc that dnf resolves in the final
# stage; that keeps shaderc on Fedora's update track rather than frozen into niri.
SHADERC_LIB_DIR="$(rpm --eval '%{_libdir}')"
export SHADERC_LIB_DIR
test -f "$SHADERC_LIB_DIR/libshaderc_shared.so"

cargo build --release --locked

# Generate completions from the binary we just built, the same set the COPR RPM ships.
compdir="$CARGO_TARGET_DIR/completions"
mkdir -p "$compdir"
"$CARGO_TARGET_DIR/release/niri" completions bash >"$compdir/niri"
"$CARGO_TARGET_DIR/release/niri" completions zsh >"$compdir/_niri"
"$CARGO_TARGET_DIR/release/niri" completions fish >"$compdir/niri.fish"

# Packaged as `niri` rather than `niri-spicy` so it upgrades cleanly over the COPR
# build: 26.4.0 sorts above yalter's 0.0.git.NNNN.hash scheme, so a plain
# `dnf install` of this file replaces it with no erasing or swapping.
cat >"$SRC/niri-spicy.spec" <<SPEC
%global srcdir $SRC/niri
%global targetdir $CARGO_TARGET_DIR
%global compdir $compdir

# systemd-rpm-macros gives us %{_userunitdir}, but %{_licensedir} comes from
# redhat-rpm-config, which isn't installed and drags in build-flag machinery we
# have no use for. Fall back to the Fedora paths only if something else hasn't
# already defined them.
%{?!_userunitdir:%global _userunitdir %{_prefix}/lib/systemd/user}
%{?!_licensedir:%global _licensedir %{_datadir}/licenses}

# Prebuilt binary; nothing here for the debuginfo machinery to chew on.
%global debug_package %{nil}
%global _build_id_links none

Name:           niri
Version:        $niri_version
Release:        1.spicy.$(date -u +%Y%m%d).git${niri_commit}%{?dist}
Summary:        A scrollable-tiling Wayland compositor (losnoco spicy fork)
License:        GPL-3.0-or-later
URL:            https://github.com/losnoco/niri

Provides:       niri-spicy = %{version}-%{release}

# Not picked up automatically: dlopen'd or runtime-only.
Requires:       mesa-dri-drivers
Requires:       mesa-libEGL
Requires:       vulkan-loader
Requires:       xwayland-satellite >= 0.7

%description
niri is a scrollable-tiling Wayland compositor.

This is losnoco's "spicy" fork (branch $NIRI_BRANCH, commit $niri_commit) built
against losnoco's smithay fork (branch $SMITHAY_BRANCH, commit $smithay_commit),
which adds HDR output support, a Vulkan renderer, window minimizing, per-output
tearing control and xdg-decoration v2.

%install
install -Dpm0755 %{targetdir}/release/niri       %{buildroot}%{_bindir}/niri
install -Dpm0755 %{srcdir}/resources/niri-session %{buildroot}%{_bindir}/niri-session

install -Dpm0644 %{srcdir}/resources/niri.service \\
    %{buildroot}%{_userunitdir}/niri.service
install -Dpm0644 %{srcdir}/resources/niri-shutdown.target \\
    %{buildroot}%{_userunitdir}/niri-shutdown.target
install -Dpm0644 %{srcdir}/resources/niri.desktop \\
    %{buildroot}%{_datadir}/wayland-sessions/niri.desktop
install -Dpm0644 %{srcdir}/resources/niri-portals.conf \\
    %{buildroot}%{_datadir}/xdg-desktop-portal/niri-portals.conf

install -Dpm0644 %{compdir}/niri \\
    %{buildroot}%{_datadir}/bash-completion/completions/niri
install -Dpm0644 %{compdir}/_niri \\
    %{buildroot}%{_datadir}/zsh/site-functions/_niri
install -Dpm0644 %{compdir}/niri.fish \\
    %{buildroot}%{_datadir}/fish/vendor_completions.d/niri.fish

install -Dpm0644 %{srcdir}/LICENSE %{buildroot}%{_licensedir}/niri/LICENSE

%files
%license %{_licensedir}/niri/LICENSE
%{_bindir}/niri
%{_bindir}/niri-session
%{_userunitdir}/niri.service
%{_userunitdir}/niri-shutdown.target
%{_datadir}/wayland-sessions/niri.desktop
%{_datadir}/xdg-desktop-portal/niri-portals.conf
%{_datadir}/bash-completion/completions/niri
%{_datadir}/zsh/site-functions/_niri
%{_datadir}/fish/vendor_completions.d/niri.fish

%changelog
* $(date -u "+%a %b %d %Y") Porcoferrum build <noreply@localhost> - $niri_version-1.spicy.$(date -u +%Y%m%d).git${niri_commit}
- Built from $NIRI_BRANCH@$niri_commit against smithay $SMITHAY_BRANCH@$smithay_commit
SPEC

rpmbuild -bb --define "_topdir $SRC/rpmbuild" "$SRC/niri-spicy.spec"

mkdir -p /rpms
cp "$SRC"/rpmbuild/RPMS/*/niri-*.rpm /rpms/
ls -la /rpms

# An unresolved macro doesn't fail rpmbuild, it packages a directory named
# literally "%{_licensedir}". Check the payload rather than trusting the macros.
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
