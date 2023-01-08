FROM python:3.11-slim

RUN apt update \
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
