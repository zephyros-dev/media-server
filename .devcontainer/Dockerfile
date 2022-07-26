# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.241.1/containers/debian/.devcontainer/base.Dockerfile

# [Choice] Debian version (use bullseye on local arm64/Apple Silicon): bullseye, buster
ARG VARIANT="buster"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

# ** [Optional] Uncomment this section to install additional packages. **
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>

ARG USERNAME=vscode

RUN mkdir -p /home/${USERNAME}/.vscode-server/extensions \
    && chown -R ${USERNAME} \
    /home/${USERNAME}/.vscode-server

RUN apt update \
    && apt install -y --no-install-recommends \
    curl \
    gettext-base \
    openssl \
    python3-pip \
    sshpass \
    unzip \
    whois \
    && rm -rf /var/lib/apt/lists/* \
    && apt autoremove -y \
    && apt clean -y

# sops
ARG SOPS_VERSION="3.7.1"
RUN curl -L -o sops.deb "https://github.com/mozilla/sops/releases/download/v${SOPS_VERSION}/sops_${SOPS_VERSION}_amd64.deb" \
    && apt install -y --no-install-recommends ./sops.deb \
    && git config --global diff.sopsdiffer.textconv "sops -d" \
    && rm -r sops.deb \
    && rm -rf /var/lib/apt/lists/* \
    && apt autoremove -y \
    && apt clean -y

# Ansible
# ARG ANSIBLE_VERSION="6.1.0"
# RUN pip install --no-cache-dir ansible==${ANSIBLE_VERSION}
RUN pip install --no-cache-dir ansible

RUN apt update \
    && apt install -y --no-install-recommends \
    fish \
    iputils-ping \
    tmux \
    && rm -rf /var/lib/apt/lists/* \
    && apt autoremove -y \
    && apt clean -y