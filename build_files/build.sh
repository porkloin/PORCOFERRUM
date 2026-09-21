#!/usr/bin/env bash
set -xeuo pipefail

# Replace bazzirco's mainline niri (yalter/niri-git Copr) with the spicy fork built
# in the niri-spicy stage. Same package name and a higher version, so this is a
# plain upgrade rather than a swap.
dnf5 install -y /niri-spicy-rpms/niri-*.rpm
rpm -q niri --qf '%{NAME} %{VERSION}-%{RELEASE}\n' | grep spicy

# The niri package owns niri.service, so installing over it drops the Wants=
# bazzirco adds in its 01-theme.sh. Put them back.
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

# niri >=26.04 dropped `keep-max-bpc-unchanged`, but the dms-greeter 1.4.6 Copr
# build (2026-04-24) still has it. Upstream fix lives at AvengeMedia/DankMaterialShell@5ceb908b.
# Remove this block once the avengemedia/danklinux Copr rebuilds dms-greeter.
#sed -i '/keep-max-bpc-unchanged/d' \
#  /usr/bin/dms-greeter \
#  /usr/share/quickshell/dms-greeter/Modules/Greetd/assets/dms-niri.kdl \
#  /usr/share/quickshell/dms-greeter/Modules/Greetd/assets/dms-greeter

dnf5 clean all
