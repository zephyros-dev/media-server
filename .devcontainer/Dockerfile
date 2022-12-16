FROM mcr.microsoft.com/devcontainers/python:3.11

ARG CANON_ARCH='dpkg --print-architecture'

USER root
RUN apt update \
    && apt install -y --no-install-recommends \
    fish \
    gettext-base \
    openssl \
    sshpass \
    tmux \
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
    ~/.ssh

COPY --chown=${USERNAME}:${USERNAME} requirements.txt .
RUN pip install \
    --no-warn-script-location \
    --requirement requirements.txt \
    --user
