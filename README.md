# PORCOFERRUM

Gaming-oriented HDR-compatible fedora-bootc image with Niri desktop.

Extends [Zirconium Jackrabbit](https://github.com/zirconium-dev/zirconium-jackrabbit) via [ublue image template](https://github.com/ublue-os/image-template), but replaces mainline Niri with the [niri spicy fork](https://github.com/losnoco/niri/tree/spicy), which adds HDR.

Beyond that, adds a few non-flatpak'd apps that I prefer to use, including:

- coolercontrol
- ghostty
- 1password + 1password-cli

[My niri settings](build_files/niri/porcoferrum.kdl) are layered over Zirconium's, and `niri-hdr on|off|toggle` switches HDR.

## Image signature

Updates must be signed with `cosign.pub`. Existing installs switch once:

    sudo bootc switch --enforce-container-sigpolicy ghcr.io/porkloin/porcoferrum:latest

## Materia

[Materia](https://primamateria.systems) keeps a machine's containers in a git repo: it installs the repo's quadlets,
starts them, and applies whatever changes you push. Here it runs rootless, as your user.

To turn it on:

1. `zjust setup-materia <repo url> [host name]`. For an `ssh://` URL it also makes a read-only deploy key and prints it
   to add to the repo.
2. `systemctl --user start materia-update.service` to apply the repo; rerun it to apply new commits.

A minimal repo:

```
MANIFEST.toml                       [Hosts.mybox]
                                    Components = ["hello"]
components/hello/MANIFEST.toml      [[Services]]
                                    Service = "hello.service"
components/hello/hello.container    a normal quadlet
```

Materia's [example repo](https://github.com/stryan/materia/tree/master/docs/example_repo) shows the rest: attributes,
templates and secrets (`attributes/<host>.age`, encrypted to the age key the recipe prints).
