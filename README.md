# PORCOFERRUM

Forked from [Zirconium](https://github.com/zirconium-dev/zirconium) via [ublue image template](https://github.com/ublue-os/image-template).

Adds mostly gaming stuff and some specific things for my system setup.

## niri-spicy

This image replaces the mainline niri that bazzirco pulls from the
[`yalter/niri-git`](https://copr.fedorainfracloud.org/coprs/yalter/niri-git/) Copr with
[losnoco's "spicy" fork](https://github.com/losnoco/niri/tree/spicy-main), which adds HDR
output, a Vulkan renderer, window minimizing, per-output tearing control and xdg-decoration v2.

Nobody packages it, so `build_files/build-niri-spicy.sh` builds it from source in its own
stage and `build_files/build.sh` installs the resulting RPM. Two things worth knowing:

- The fork's `Cargo.toml` patches smithay to `path = "../smithay"`, so
  [`losnoco/smithay@spicy-master`](https://github.com/losnoco/smithay/tree/spicy-master) is
  cloned as a **sibling** of the niri checkout. It won't build otherwise.
- Both repos track branch HEAD and the build is `--locked`. If losnoco bumps smithay without
  refreshing niri's lockfile, the image build fails loudly rather than quietly resolving to
  different crate versions.

The package keeps the name `niri` (version `26.4.0`, release `…spicy…`) so it upgrades over the
Copr build instead of needing a swap. `rpm -q niri` tells you which one you're on.
