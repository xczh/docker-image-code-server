##############################################
# Stage 1: Build Essential
##############################################

FROM ubuntu:24.04 AS slim

LABEL maintainer.name="xczh" \
      maintainer.email="xczh.me@foxmail.com" \
      description="Run Visual Studio in Browser"

ARG TARGETOS
ARG TARGETARCH
ARG CODE_VERSION

SHELL ["/bin/bash", "-c", "-eux", "-o", "pipefail"]

# Notice: you can pass env $HASHED_PASSWORD at runtime.
ENV LANG=en_US.UTF-8 PASSWORD=hello_coder CODE_ARGS=

RUN apt-get update && \
    LANG=C.UTF-8 DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -o=Dpkg::Use-Pty=0 \
        apt-utils \
        bash-completion \
        ca-certificates \
        command-not-found \
        curl \
        file \
        git \
        git-lfs \
        gnupg \
        htop \
        iproute2 \
        iputils-ping \
        iputils-tracepath \
        jq \
        less \
        locales \
        lsb-release \
        lshw \
        lsof \
        man-db \
        manpages \
        mtr-tiny \
        nano \
        netcat-openbsd \
        net-tools \
        openssh-client \
        openssl \
        psmisc \
        python3 \
        python3-venv \
        sudo \
        tcpdump \
        time \
        tmux \
        unzip \
        vim-tiny \
        wget \
        zip \
      && \
    locale-gen en_US.UTF-8 zh_CN.UTF-8 && \
    update-locale LANG=en_US.UTF-8 && \
    if [ -z "${CODE_VERSION}" ]; then \
      CODE_VERSION=$(curl -sX GET https://api.github.com/repos/coder/code-server/releases/latest \
        | awk '/tag_name/{print $4;exit}' FS='[""]' | sed 's|^v||'); \
    fi && \
    CODE_ARCH=$([ "${TARGETARCH}" = "arm" ] && echo -n "armv7l" || echo -n "${TARGETARCH}") && \
    CODE_SERVER_URL="https://github.com/coder/code-server/releases/download/v${CODE_VERSION}/code-server-${CODE_VERSION}-${TARGETOS}-${CODE_ARCH}.tar.gz" && \
    echo "Download code-server from ${CODE_SERVER_URL} ..." && \
    curl -o /tmp/code-server.tar.gz -L "${CODE_SERVER_URL}" && \
    mkdir -p /app /volume/data /volume/extensions /volume/workspace && \
    tar -xvf /tmp/code-server.tar.gz -C /app --strip-components=1 && \
    apt-get clean -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* /var/log/* /tmp/* /root/.cache && \
#
# Fix: Since Ubuntu 24.04, user 'ubuntu' become the default user as uid '1000',
#      so we no more need this.
#   adduser --uid 1000 --gecos '' --disabled-password coder && \
#
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd && \
    chown -R 1000:1000 /volume

WORKDIR /volume/workspace

USER ubuntu

# Warn: If any build steps change the data within the volume after VOLUME has been declared, 
#       those changes will be discarded.
VOLUME /volume

EXPOSE 8080/tcp

HEALTHCHECK --start-period=10s --interval=60s --timeout=5s --retries=3 \
  CMD grep -q -- '--cert' /proc/1/cmdline && { curl -f --insecure https://127.0.0.1:8080/healthz || exit 1; } || { curl -f http://127.0.0.1:8080/healthz || exit 1; }

# Notice: before run, ensure volume path permission:
#     chown -R 1000:1000 /path/to/host/volume
CMD /app/bin/code-server --disable-telemetry --bind-addr 0.0.0.0:8080 --auth password --user-data-dir /volume/data --extensions-dir /volume/extensions ${CODE_ARGS} /volume/workspace


##############################################
# Stage 2: Full Development Environment
#  C, C++, Go, Rust, Miniconda3
##############################################

FROM slim AS full

RUN sudo apt-get update && \
# C, C++
    LANG=C.UTF-8 DEBIAN_FRONTEND=noninteractive sudo apt-get install -y --no-install-recommends -o=Dpkg::Use-Pty=0 \
      build-essential \
      cmake \
      gdb \
      && \
    gcc --version && \
    g++ --version && \
# Go
# Support platform: linux/amd64, linux/arm64, linux/armv6l
    GOLANG_ARCH=$([ "${TARGETARCH}" = "arm" ] && echo -n "armv6l" || echo -n "${TARGETARCH}") && \
    GOLANG_LATEST_FILENAME=$(curl https://go.dev/dl/?mode=json | grep -o "go.*.linux-${GOLANG_ARCH}.tar.gz" | head -n 1 | tr -d '\r\n') && \
    GOLANG_URL="https://go.dev/dl/${GOLANG_LATEST_FILENAME}" && \
    echo "Download golang from ${GOLANG_URL} ..." && \
    curl -sSL -o /tmp/golang.tar.gz "${GOLANG_URL}" && \
    sudo tar -zxf /tmp/golang.tar.gz -C /usr/local && \
    echo 'case ":${PATH}:" in *:"/usr/local/go/bin":*) ;; *) export PATH="/usr/local/go/bin:$PATH";; esac' >> ~/.bashrc && \
    /usr/local/go/bin/go version && \
# Rust
# Support platform: 
# Tier 1: x86_64-unknown-linux-gnu, aarch64-unknown-linux-gnu
# Tier 2: armv7-unknown-linux-gnueabihf
# See: https://doc.rust-lang.org/nightly/rustc/platform-support.html
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal && \
    ~/.cargo/bin/rustup --version && \
    ~/.cargo/bin/cargo --version && \
    ~/.cargo/bin/rustc --version && \
# Miniconda3
# Support platform: x86_64, aarch64
    if [ "${TARGETARCH}" = "arm64" ]; then \
      MINICONDA3_ARCH="aarch64"; \
    elif [ "${TARGETARCH}" = "amd64" ]; then \
      MINICONDA3_ARCH="x86_64"; \
    else \
      MINICONDA3_ARCH=""; \
      echo "Miniconda3 is NOT installed for ${TARGETARCH}."; \
    fi && \
    if [ -n "${MINICONDA3_ARCH}" ]; then \
      LANG=C.UTF-8 DEBIAN_FRONTEND=noninteractive sudo apt-get install -y --no-install-recommends -o=Dpkg::Use-Pty=0 \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender1; \
      curl -sSL -o /tmp/miniconda3.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${MINICONDA3_ARCH}.sh; \
      bash /tmp/miniconda3.sh -b; \
      bash -c 'source /home/ubuntu/miniconda3/bin/activate && conda init && conda config --set auto_activate_base False && conda info && conda clean -afy'; \
      find /home/ubuntu/miniconda3/ -follow -type f -name '*.a' -delete; \
      find /home/ubuntu/miniconda3/ -follow -type f -name '*.js.map' -delete; \
    fi && \
# Cleanup
    sudo apt-get clean -y && \
    sudo apt-get autoremove -y && \
    sudo rm -rf /var/lib/apt/lists/* /var/tmp/* /var/log/* /tmp/* /root/.cache /home/ubuntu/.rustup/tmp/*
