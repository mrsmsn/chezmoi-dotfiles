image := "chezmoi-dotfiles-ci"

# Default: run all containerised CI checks
default: ci

# Build the container image used by every test recipe
build:
    podman build -t {{image}} -f Containerfile .

# Run all non-bootstrap CI checks (lint + template tests)
ci: lint template-variants template-shellcheck

# Reproduce the `lint` GH Actions job in a clean Linux container
lint: build
    podman run --rm -v "$PWD":/repo:Z -w /repo {{image}} ./ci/lint.sh

# Reproduce the `template-variants` job
template-variants: build
    podman run --rm -v "$PWD":/repo:Z -w /repo {{image}} ./ci/template-variants.sh

# Reproduce the `template-shellcheck` job
template-shellcheck: build
    podman run --rm -v "$PWD":/repo:Z -w /repo {{image}} ./ci/template-shellcheck.sh
