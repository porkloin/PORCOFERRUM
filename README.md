# PORCOFERRUM

Gaming-oriented HDR-compatible fedora-bootc image with Niri desktop.

Extends [Zirconium Jackrabbit](https://github.com/zirconium-dev/zirconium-jackrabbit) via [ublue image template](https://github.com/ublue-os/image-template), but replaces mainline Niri with the [niri spicy fork](<https://github.com/losnoco/niri/tree/spicy>, which adds HDR.

Beyond that, adds a few non-flatpak'd apps that I prefer to use, including:

- coolercontrol
- ghostty
- 1password + 1password-cli

## Image signature

Updates must be signed with `cosign.pub`. Existing installs switch once:

    sudo bootc switch --enforce-container-sigpolicy ghcr.io/porkloin/porcoferrum:latest

Niri additions (Steam window rules, DualSense touchpad off, Zen picture-in-picture, HDR) go through Zirconium's
system-wide override, `/etc/niri/local.kdl`, so `~/.config/niri` stays Zirconium's and keeps getting its updates.
`niri-hdr on|off|toggle|status` turns HDR on an output on and off, from DMS's output config.
