FROM ghcr.io/astral-sh/uv:0.6.14-debian-slim@sha256:b3d5f8d92ca959c74c9f247c2a2dfc4b3f7a064ca3a99690445abda964e6aadc

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update \
    && apt install -y --no-install-recommends \
    curl \
    docker-compose \
    fish \
    git \
    # Ansbile
    openssh-client \
    openssl \
    sshpass \
    # Openwrt
    rsync \
    # Fix locales for python
    # https://stackoverflow.com/a/28406007
    locales \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen

ARG USERNAME
ARG workspaceFolder
RUN useradd --create-home --shell /bin/bash ${USERNAME}

USER ${USERNAME}
RUN mkdir -p \
    ~/.ansible \
    ~/.cache \
    ~/.config/sops/age \
    ~/.local/bin \
    ~/.local/share/aquaproj-aqua \
    ~/.local/share/fish \
    ~/.local/share/uv \
    ~/.ssh \
    ~/.terraform.d/plugin-cache \
    ~/bin

ENV PATH=/home/${USERNAME}/.local/share/aquaproj-aqua/bin:${workspaceFolder}/.venv/bin:/home/${USERNAME}/bin:$PATH
