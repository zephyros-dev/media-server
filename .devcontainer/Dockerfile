FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm@sha256:a067e746fb8291fac357e5fbae6f68f1e34e44cfa9d318656ee9d1708ce9d464

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update \
    && apt install -y --no-install-recommends \
    docker-compose \
    gettext-base \
    guix \
    openssl \
    sshpass \
    whois

ARG USERNAME
ARG UID=1000

USER ${USERNAME}
RUN mkdir -p \
    ~/.ansible \
    ~/.cache/pip \
    ~/.config/sops/age \
    ~/.local/share/aquaproj-aqua/bin \
    ~/.local/share/aquaproj-aqua/pkgs \
    ~/.local/share/aquaproj-aqua/registries \
    ~/.local/share/fish \
    ~/.ssh \
    ~/.terraform.d/plugin-cache \
    ~/bin

COPY --chown=${USERNAME}:${USERNAME} requirements.txt .
RUN \
    --mount=type=cache,uid=${UID},target=/home/${USERNAME}/.cache/pip \
    pip install \
    --no-warn-script-location \
    --requirement requirements.txt \
    --user

ENV PATH=/home/${USERNAME}/.local/share/aquaproj-aqua/bin:/home/${USERNAME}/node_modules/.bin:/home/${USERNAME}/bin:/home/${USERNAME}/.guix-profile/bin:$PATH

ENV PODMAN_VERSION=v5.1.2
