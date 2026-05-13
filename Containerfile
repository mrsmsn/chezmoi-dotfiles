FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        zsh shellcheck jq curl ca-certificates git sed \
    && rm -rf /var/lib/apt/lists/*

# Install chezmoi via the official one-line installer.
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin

WORKDIR /repo
