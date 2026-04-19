#! /bin/bash

sudo apt-get update
# Set up uv for Python dependency management.
# TODO: Consider using a system-provided package here.
sudo apt-get install -y curl
curl -LsSf https://astral.sh/uv/0.6.12/install.sh | sh
# Ensure uv is in the PATH
export PATH="${PATH}:$HOME/.local/bin"
# Create a venv for use by uv, without needing a pyproject.toml file for the project.
uv venv
uv tool update-shell
