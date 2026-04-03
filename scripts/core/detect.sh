#!/usr/bin/env bash
set -euo pipefail

detect_gpu() {
    if lspci | grep -qi nvidia; then
        echo "nvidia"
    elif lspci | grep -qi amd; then
        echo "amd"
    else
        echo "intel"
    fi
}

detect_env() {
    if systemd-detect-virt --quiet; then
        echo "vm"
    else
        echo "baremetal"
    fi
}

GPU=$(detect_gpu)
ENV=$(detect_env)

echo "{\"gpu\":\"$GPU\",\"env\":\"$ENV\"}"
