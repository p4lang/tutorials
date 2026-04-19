#! /bin/bash

sudo apt-get update
# Set up uv for Python dependency management.
# TODO: Consider using a system-provided package here.
sudo apt-get install -y curl
curl -LsSf https://astral.sh/uv/0.6.12/install.sh | sh
# Ensure uv is in the PATH
export PATH="${PATH}:$HOME/.local/bin"
uv sync
uv tool update-shell
