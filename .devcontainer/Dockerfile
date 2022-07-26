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
    ansible

RUN apt update \
    && apt install -y --no-install-recommends \
    fish \
    iputils-ping \
    tmux \
    && rm -rf /var/lib/apt/lists/* \
    && apt autoremove -y \
    && apt clean -y