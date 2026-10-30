# Both stages below build FROM this, so it lives in one place.
ARG BASE_IMAGE=ghcr.io/zirconium-dev/zirconium-jackrabbit:latest

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

### MATERIA
## Release binary, verified against the pinned checksum.
FROM ${BASE_IMAGE} AS materia
ARG MATERIA_VERSION=0.8.0
ARG MATERIA_SHA256=5ac4a44a54bbdc71f87db4d168c0246f6b272208d6a0a28e66575ab649bcf09d
RUN set -eux; \
    mkdir -p /tmp/materia/out; \
    cd /tmp/materia; \
    tarball="materia-v${MATERIA_VERSION}-amd64.tar.gz"; \
    curl -fsSLO "https://github.com/stryan/materia/releases/download/v${MATERIA_VERSION}/$tarball"; \
    echo "${MATERIA_SHA256}  $tarball" | sha256sum -c; \
    tar -xzf "$tarball" -C out

### NIRI-SPICY
FROM ${BASE_IMAGE} AS niri-spicy

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
  --mount=type=cache,dst=/var/cache \
  --mount=type=tmpfs,dst=/tmp \
  /ctx/build-niri-spicy.sh

FROM ${BASE_IMAGE}

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

COPY image/ /
COPY cosign.pub /etc/pki/containers/porcoferrum.pub
COPY --from=materia /tmp/materia/out/bin/materia /usr/bin/materia
COPY --from=materia /tmp/materia/out/man/ /usr/share/man/

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
  --mount=type=bind,from=niri-spicy,source=/rpms,target=/niri-spicy-rpms \
  --mount=type=cache,dst=/var/cache \
  --mount=type=cache,dst=/var/log \
  --mount=type=tmpfs,dst=/tmp \
  /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
