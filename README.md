# PORCOFERRUM

Forked from [Zirconium](https://github.com/zirconium-dev/zirconium) via [ublue image template](https://github.com/ublue-os/image-template).

Adds mostly gaming stuff and some specific things for my system setup.

## niri-spicy

Replaces bazzirco's mainline niri from the
[`yalter/niri-git`](https://copr.fedorainfracloud.org/coprs/yalter/niri-git/) Copr with
[losnoco's spicy fork](https://github.com/losnoco/niri/tree/spicy-main): HDR output, a Vulkan
renderer, window minimizing, per-output tearing control, xdg-decoration v2.

Nobody packages it, so `build_files/build-niri-spicy.sh` builds an RPM in its own stage and
`build_files/build.sh` installs it. Gotchas:

- The fork patches smithay to `path = "../smithay"`, so
  [`losnoco/smithay@spicy-master`](https://github.com/losnoco/smithay/tree/spicy-master) must be
  cloned as a **sibling** of the niri checkout.
- Both repos track branch HEAD, built `--locked`. A smithay bump without a matching niri
  lockfile fails the build instead of silently resolving different crates.

The package is still named `niri` (`26.4.0-…spicy…`), so it upgrades over the Copr build rather
than needing a swap. Check with `rpm -q niri`.
