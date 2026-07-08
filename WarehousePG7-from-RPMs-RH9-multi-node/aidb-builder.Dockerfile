# syntax=docker/dockerfile:1
#
# Builder image for the AIDB pgrx extension against WarehousePG 7 (RH9).
# The image installs WHPG the same way as the main Dockerfile, then adds
# a Rust toolchain and cargo-pgrx from EDB's pgrx fork. Runtime bind-mount
# your AIDB checkout at /src and an output dir at /out.
#
# Cargo needs to clone from private EDB GitHub repos (pgrx, pgfs) both while
# building this image and while running `cargo pgrx package`. Provide a
# GitHub token with `repo` scope via the GH_API_TOKEN environment variable on
# the host — it's forwarded as a BuildKit secret at build time and as a
# regular env var at run time; it is never baked into any image layer.
#
# Build the builder:
#   DOCKER_BUILDKIT=1 docker build \
#       --platform=linux/amd64 \
#       --secret id=edbtoken_secret,env=EDBTOKEN \
#       --secret id=edbrepository_secret,env=EDBREPOSITORY \
#       --secret id=gh_token,env=GH_API_TOKEN \
#       -f aidb-builder.Dockerfile -t whpg7-aidb-builder .
#
# Build the extension (from this directory):
#   mkdir -p aidb-out
#   docker run --rm --platform=linux/amd64 \
#       -e GH_API_TOKEN \
#       -v $(cd ../../aidb && pwd):/src:ro \
#       -v $(pwd)/aidb-out:/out \
#       -v whpg7-aidb-cargo-target:/tmp/target \
#       -v whpg7-aidb-cargo-registry:/opt/cargo/registry \
#       whpg7-aidb-builder
#
# Artifacts land in ./aidb-out/{lib,extension} — copy into each WHPG
# container with the aidb-install.sh helper alongside this file.

ARG PGRX_BRANCH=edb-v0.19.1

FROM rockylinux:9

ENV container=docker
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# --- install WHPG the same way the runtime image does ---
RUN dnf update -y \
 && dnf install -y epel-release \
 && dnf update -y

RUN --mount=type=secret,id=edbtoken_secret \
    --mount=type=secret,id=edbrepository_secret \
    curl -u token:$(cat /run/secrets/edbtoken_secret) -1sLf \
        https://downloads.enterprisedb.com/basic/$(cat /run/secrets/edbrepository_secret)/setup.rpm.sh \
        -o /root/setup.rpm.sh \
 && chmod +x /root/setup.rpm.sh \
 && /root/setup.rpm.sh

RUN dnf install -y warehouse-pg-7 edb-whpg7-pgvector

# --- build toolchain for AIDB (mirrors aidb/.mise/scripts/install-deps.sh dnf branch) ---
RUN dnf groupinstall -y "Development Tools" \
 && dnf install -y --enablerepo=crb \
        cmake golang gcc-c++ make bison flex \
        readline-devel perl-IPC-Run \
        clang clang-devel \
        libcurl-devel openssl-devel \
        libyaml libyaml-devel libuv-devel \
        git ca-certificates \
 && dnf clean all

# Intel oneAPI MKL — needed AT BUILD TIME. candle's build.rs emits
# `-lmkl_rt` only if MKL is installed here; otherwise the resulting
# aidb.so has an undefined `hgemm_` (etc.) with no NEEDED entry, and
# postgres's dlopen(RTLD_NOW) refuses to load it at runtime.
# Same yum repo + package as the WHPG runtime image so build and runtime
# stay on the same MKL version.
RUN printf '%s\n' \
        '[oneAPI]' \
        'name=Intel oneAPI repository' \
        'baseurl=https://yum.repos.intel.com/oneapi' \
        'enabled=1' \
        'gpgcheck=1' \
        'repo_gpgcheck=1' \
        'gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB' \
        > /etc/yum.repos.d/oneAPI.repo \
 && dnf install -y intel-oneapi-mkl-devel \
 && dnf clean all

# --- Rust (stable) + cargo-pgrx from EDB fork ---
ENV CARGO_HOME=/opt/cargo \
    RUSTUP_HOME=/opt/rustup \
    PATH=/opt/cargo/bin:/usr/local/greenplum-db/bin:/usr/local/bin:/usr/bin:/bin

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- --default-toolchain stable --profile minimal -y

ARG PGRX_BRANCH
# Use the host's GH_API_TOKEN (via BuildKit secret) to fetch EDB's private
# pgrx fork. The token is written to a throwaway gitconfig under /tmp so it
# never ends up in ~/.gitconfig or the image layer.
RUN --mount=type=secret,id=gh_token \
    if [ -s /run/secrets/gh_token ]; then \
        export GIT_CONFIG_GLOBAL=/tmp/gitconfig.build; \
        git config --file "$GIT_CONFIG_GLOBAL" \
            "url.https://x-access-token:$(cat /run/secrets/gh_token)@github.com/.insteadOf" \
            "https://github.com/"; \
        export CARGO_NET_GIT_FETCH_WITH_CLI=true; \
    fi; \
    cargo install --locked \
        --git https://github.com/EnterpriseDB/pgrx \
        --branch ${PGRX_BRANCH} \
        cargo-pgrx; \
    rm -f /tmp/gitconfig.build; \
    rm -rf /opt/cargo/registry/src

# `cargo pgrx package` requires $PGRX_HOME to exist. Point it at a shared
# location and register WHPG's pg_config so init doesn't try to download a
# stock Postgres (--pg12=<path> takes an existing pg_config).
ENV PGRX_HOME=/opt/pgrx
RUN mkdir -p $PGRX_HOME \
 && cargo pgrx init --pg12=/usr/local/greenplum-db/bin/pg_config

# Keep cargo build output off the (bind-mounted) source tree for speed.
# Mount a named volume here to cache across invocations.
ENV CARGO_TARGET_DIR=/tmp/target

WORKDIR /src

# `cargo pgrx package` writes into $CARGO_TARGET_DIR/<profile>/aidb-pgXX/,
# following the target PG's install layout. We then flatten the two files
# we actually need into /out for easy `docker cp` later.
#
# --features whpg,pg12 : whpg brings WHPG bindings; pg12 is a marker cargo-pgrx
#                        insists on (see aidb/Cargo.toml:41-51).
CMD set -eux; \
    if [ -n "${GH_API_TOKEN:-}" ]; then \
        export GIT_CONFIG_GLOBAL=/tmp/gitconfig.run; \
        git config --file "$GIT_CONFIG_GLOBAL" \
            "url.https://x-access-token:${GH_API_TOKEN}@github.com/.insteadOf" \
            "https://github.com/"; \
        export CARGO_NET_GIT_FETCH_WITH_CLI=true; \
    fi; \
    cargo pgrx package \
        --features whpg,pg12 \
        --pg-config /usr/local/greenplum-db/bin/pg_config; \
    pkg_root=$(ls -d /tmp/target/release/aidb-pg*/ | head -n1); \
    rm -rf /out/lib /out/extension; \
    mkdir -p /out/lib /out/extension; \
    find "${pkg_root}" -name 'aidb.so'       -exec cp -v {} /out/lib/       \;; \
    find "${pkg_root}" -name 'aidb.control'  -exec cp -v {} /out/extension/ \;; \
    find "${pkg_root}" -name 'aidb--*.sql'   -exec cp -v {} /out/extension/ \;; \
    echo "Done. Artifacts in /out (host: ./aidb-out)."
