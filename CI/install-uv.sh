#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The P4 Language Consortium
# SPDX-License-Identifier: Apache-2.0

set -eu

UV_VERSION="${UV_VERSION:-0.11.7}"
UV_INSTALL_DIR="${HOME}/.local/bin"

if command -v uv >/dev/null 2>&1; then
    exit 0
fi

mkdir -p "${UV_INSTALL_DIR}"

if command -v curl >/dev/null 2>&1; then
    env UV_UNMANAGED_INSTALL="${UV_INSTALL_DIR}" \
        sh -c "$(curl -LsSf https://astral.sh/uv/${UV_VERSION}/install.sh)"
elif command -v wget >/dev/null 2>&1; then
    env UV_UNMANAGED_INSTALL="${UV_INSTALL_DIR}" \
        sh -c "$(wget -qO- https://astral.sh/uv/${UV_VERSION}/install.sh)"
else
    echo "Neither curl nor wget is available to install uv" >&2
    exit 1
fi

export PATH="${UV_INSTALL_DIR}:${PATH}"
if [ -n "${GITHUB_PATH:-}" ]; then
    echo "${UV_INSTALL_DIR}" >> "${GITHUB_PATH}"
fi
