FROM mcr.microsoft.com/vscode/devcontainers/base

ARG CANON_ARCH='dpkg --print-architecture'

ARG PRECOMMIT_HOOK_VERSION
ENV PRECOMMIT_HOOK_VERSION ${PRECOMMIT_HOOK_VERSION}

ARG PRECOMMIT_CONVENTIONAL_COMMIT
ENV PRECOMMIT_CONVENTIONAL_COMMIT ${PRECOMMIT_CONVENTIONAL_COMMIT}

ARG USERNAME

USER ${USERNAME}
RUN mkdir -p ~/.vscode-server

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

ARG ANSIBLE_VERSION
RUN pip install --no-cache-dir ansible==${ANSIBLE_VERSION}

ARG ANSIBLE_LINT_VERSION
ENV ANSIBLE_LINT_VERSION ${ANSIBLE_LINT_VERSION}
RUN pip install --no-cache-dir ansible-lint==${ANSIBLE_LINT_VERSION}

ARG PRECOMMIT_VERSION
RUN pip install --no-cache-dir pre-commit==${PRECOMMIT_VERSION}
