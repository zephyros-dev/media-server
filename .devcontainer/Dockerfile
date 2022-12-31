FROM mcr.microsoft.com/devcontainers/python:3.11

ARG CANON_ARCH='dpkg --print-architecture'

USER root
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update \
    && apt install -y --no-install-recommends \
    fish \
    gettext-base \
    openssl \
    sshpass \
    tmux \
    whois

ARG SOPS_VERSION
RUN curl -Lo sops.deb https://github.com/mozilla/sops/releases/download/v${SOPS_VERSION}/sops_${SOPS_VERSION}_$(eval ${CANON_ARCH}).deb \
    && apt install -y --no-install-recommends ./sops.deb \
    && git config --global diff.sopsdiffer.textconv "sops -d" \
    && rm -r sops.deb

ARG USERNAME
ARG UID=1000

USER ${USERNAME}
RUN mkdir -p \
    ~/.ansible \
    ~/.cache/pip \
    ~/.config/sops/age \
    ~/.local/share/fish \
    ~/.ssh

COPY --chown=${USERNAME}:${USERNAME} requirements.txt .
RUN \
    --mount=type=cache,uid=${UID},target=/home/${USERNAME}/.cache/pip \
    pip install \
    --no-warn-script-location \
    --requirement requirements.txt \
    --user
