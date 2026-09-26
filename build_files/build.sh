#!/usr/bin/env bash
set -xeuo pipefail

# xwayland satellite pls
# https://github.com/Supreeeme/xwayland-satellite/issues/468
XWS_ARCH="$(rpm -E '%{_arch}')"
dnf5 install -y \
  "https://kojipkgs.fedoraproject.org/packages/xwayland-satellite/0.8.1/1.fc44/${XWS_ARCH}/xwayland-satellite-0.8.1-1.fc44.${XWS_ARCH}.rpm"
rpm -q xwayland-satellite | grep -q '^xwayland-satellite-0.8.1-1\.fc44'

# Spicy fork from the niri-spicy stage
dnf5 install -y /niri-spicy-rpms/niri-*.rpm
rpm -q niri --qf '%{NAME} %{VERSION}-%{RELEASE}\n' | grep spicy

dnf5 -y copr enable codifryed/CoolerControl
dnf5 install -y coolercontrol liquidctl
dnf5 -y copr disable codifryed/CoolerControl

# Ghostty
dnf5 install -y --nogpgcheck \
  --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
  terra-release
dnf5 install -y ghostty
dnf5 remove -y terra-release terra-gpg-keys

dnf5 clean all
