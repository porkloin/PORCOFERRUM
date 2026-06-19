#!/usr/bin/env bash
set -xeuo pipefail

dnf5 -y copr enable codifryed/CoolerControl
dnf5 install -y coolercontrol liquidctl
dnf5 -y copr disable codifryed/CoolerControl

# niri >=26.04 dropped `keep-max-bpc-unchanged`, but the dms-greeter 1.4.6 Copr
# build (2026-04-24) still has it. Upstream fix lives at AvengeMedia/DankMaterialShell@5ceb908b.
# Remove this block once the avengemedia/danklinux Copr rebuilds dms-greeter.
sed -i '/keep-max-bpc-unchanged/d' \
    /usr/bin/dms-greeter \
    /usr/share/quickshell/dms-greeter/Modules/Greetd/assets/dms-niri.kdl \
    /usr/share/quickshell/dms-greeter/Modules/Greetd/assets/dms-greeter

dnf5 clean all
