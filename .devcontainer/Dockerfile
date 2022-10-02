FROM mcr.microsoft.com/vscode/devcontainers/base

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
    tmux \
    && rm -rf /var/lib/apt/lists/* \
    && apt autoremove -y \
    && apt clean -y

ARG SOPS_VERSION
RUN curl -L -o sops.deb "https://github.com/mozilla/sops/releases/download/v${SOPS_VERSION}/sops_${SOPS_VERSION}_amd64.deb" \
    && apt install -y --no-install-recommends ./sops.deb \
    && git config --global diff.sopsdiffer.textconv "sops -d" \
    && rm -r sops.deb \
    && rm -rf /var/lib/apt/lists/* \
    && apt autoremove -y \
    && apt clean -y

ARG ANSIBLE_VERSION
RUN pip install --no-cache-dir ansible=="${ANSIBLE_VERSION}"
