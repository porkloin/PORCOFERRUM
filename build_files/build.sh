#!/usr/bin/env bash
set -xeuo pipefail

dnf5 -y copr enable codifryed/CoolerControl
dnf5 install -y coolercontrol liquidctl
dnf5 -y copr disable codifryed/CoolerControl


# Moonshine WSI Vulkan layer
# Build from source since there are no prebuilt binaries in releases.
MOONSHINE_VERSION="v0.10.0"

dnf5 install -y rust cargo clang cmake gcc-c++ wayland-devel
curl -Lo /tmp/moonshine.tar.gz "https://github.com/hgaiser/moonshine/archive/refs/tags/${MOONSHINE_VERSION}.tar.gz"
tar -xzf /tmp/moonshine.tar.gz -C /tmp
cd /tmp/moonshine-${MOONSHINE_VERSION#v}
CARGO_HOME=/tmp/cargo cargo build --release -p moonshine-wsi

install -Dm755 target/release/libmoonshine_wsi.so /usr/lib/moonshine/vulkan-layers/libmoonshine_wsi.so
install -Dm644 dist/VkLayer_moonshine_wsi.json /usr/share/vulkan/implicit_layer.d/VkLayer_moonshine_wsi.json
install -Dm644 dist/60-moonshine.rules /usr/lib/udev/rules.d/60-moonshine.rules

# Clean up build deps to keep image small. /tmp is tmpfs so build artifacts
# are automatically discarded.
cd /
dnf5 remove -y rust cargo clang cmake gcc-c++ wayland-devel
dnf5 clean all
