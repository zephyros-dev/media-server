FROM mcr.microsoft.com/devcontainers/base:debian@sha256:4807916fa13f4f2a4d1ced226a31f71bc49e40864bf0825e7196f0a52a535a2c

# Use the same image as CI, otherwise we could've used just the version
COPY --from=ghcr.io/astral-sh/uv:0.6.5-debian-slim@sha256:1cea8bcdc94a2f2539c90c46bef9902f8afa7269f5fbde4f4605722866657a15 /uv /uvx /bin/

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update \
    && apt install -y --no-install-recommends \
    docker-compose \
    fish \
    gettext-base \
    openssl \
    sshpass \
    whois

ARG USERNAME
ARG UID=1000

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

ENV PATH=/home/${USERNAME}/.local/share/aquaproj-aqua/bin:/home/${USERNAME}/bin:$PATH
