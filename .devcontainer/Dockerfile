FROM mcr.microsoft.com/vscode/devcontainers/base:debian@sha256:7da3f9f54c3cca6340548070251050025a1b1ae3ab1f1596e2ef7d73d5cba8c5

ARG CANON_ARCH='dpkg --print-architecture'

USER root
RUN apt update \
    && apt install -y --no-install-recommends \
    curl \
    fish \
    gettext-base \
    openssl \
    python3-pip \
    sshpass \
    tmux \
    unzip \
    whois \
    && rm -rf /var/lib/apt/lists/* \
    && apt autoremove -y \
    && apt clean -y

ARG SOPS_VERSION
RUN curl -Lo sops.deb https://github.com/mozilla/sops/releases/download/v${SOPS_VERSION}/sops_${SOPS_VERSION}_$(eval ${CANON_ARCH}).deb \
    && apt install -y --no-install-recommends ./sops.deb \
    && git config --global diff.sopsdiffer.textconv "sops -d" \
    && rm -r sops.deb \
    && rm -rf /var/lib/apt/lists/* \
    && apt autoremove -y \
    && apt clean -y

ARG USERNAME

USER ${USERNAME}
RUN mkdir -p \
    ~/.ansible \
    ~/.config/sops/age \
    ~/.local/share/fish \
    ~/.ssh \
    ~/.vscode-server

COPY --chown=${USERNAME}:${USERNAME} requirements.txt .
RUN pip install --no-warn-script-location --requirement requirements.txt
