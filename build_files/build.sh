#!/usr/bin/env bash
set -xeuo pipefail

# 0.8.2's popup/focus handling instantly dismisses Steam's CEF context menus:
# https://github.com/Supreeeme/xwayland-satellite/issues/468
# The repos dropped 0.8.1 when 0.8.2 went stable, so pull it from koji, which
# keeps every build. Remove once a fix ships.
XWS_ARCH="$(rpm -E '%{_arch}')"
dnf5 install -y \
    "https://kojipkgs.fedoraproject.org/packages/xwayland-satellite/0.8.1/1.fc44/${XWS_ARCH}/xwayland-satellite-0.8.1-1.fc44.${XWS_ARCH}.rpm"
rpm -q xwayland-satellite | grep -q '^xwayland-satellite-0.8.1-1\.fc44'

# Spicy fork from the niri-spicy stage. Same name, higher version, so it's a
# plain upgrade over bazzirco's Copr niri.
dnf5 install -y /niri-spicy-rpms/niri-*.rpm
rpm -q niri --qf '%{NAME} %{VERSION}-%{RELEASE}\n' | grep spicy

# Installing over niri.service drops the Wants= bazzirco adds in 01-theme.sh.
add_wants_niri() {
  sed -i "s/\[Unit\]/\[Unit\]\nWants=$1/" "/usr/lib/systemd/user/niri.service"
}
add_wants_niri udiskie.service
add_wants_niri foot-server.service
cat /usr/lib/systemd/user/niri.service

dnf5 -y copr enable codifryed/CoolerControl
dnf5 install -y coolercontrol liquidctl
dnf5 -y copr disable codifryed/CoolerControl

dnf5 install -y --enablerepo=terra ghostty

dnf5 clean all
