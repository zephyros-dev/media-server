FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm@sha256:3f630cfc7a9e7b3073601535de80ea8193f3257a96a7e430b327942af4d9b575

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update \
    && apt install -y --no-install-recommends \
    docker-compose \
    fish \
    gettext-base \
    # guix \
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
