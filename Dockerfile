FROM python:3.11-slim

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update \
    && apt install -y --no-install-recommends \
    curl \
    openssh-client \
    openssl \
    sshpass \
    tar \
    whois

ENV PATH=/root/.local/share/aquaproj-aqua/bin:$PATH

RUN \
    --mount=type=cache,target=/root/.cache/pip \
    pip install \
    --no-warn-script-location \
    ansible
