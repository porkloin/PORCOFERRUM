#!/usr/bin/env bash
set -xeuo pipefail

dnf5 -y copr enable codifryed/CoolerControl
dnf5 install -y coolercontrol liquidctl
dnf5 -y copr disable codifryed/CoolerControl


dnf5 clean all
