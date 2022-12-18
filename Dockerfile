FROM python:3.11-slim

ARG CANON_ARCH='dpkg --print-architecture'

RUN apt update \
    && apt install -y --no-install-recommends \
    curl \
    openssh-client \
    openssl \
    sshpass \
    tar \
    whois \
    && rm -rf /var/lib/apt/lists/* \
    && apt autoremove -y \
    && apt clean -y

ARG SOPS_VERSION="3.7.3"
RUN curl -Lo sops.deb https://github.com/mozilla/sops/releases/download/v${SOPS_VERSION}/sops_${SOPS_VERSION}_$(eval ${CANON_ARCH}).deb \
    && apt install -y --no-install-recommends ./sops.deb \
    && rm -r sops.deb \
    && rm -rf /var/lib/apt/lists/* \
    && apt autoremove -y \
    && apt clean -y

# ARG USER=rootless

# ARG UID=1000
# RUN groupadd --system ${USER} --gid ${UID} \
#     && useradd --no-log-init --create-home --system --gid ${USER} ${USER} --uid ${UID}

# USER ${USER}

# ENV PATH="/home/${USER}/.local/bin:$PATH"

RUN pip install \
    --no-warn-script-location \
    # --user \
    ansible
