#!/usr/bin/env bash
set -euo pipefail

chmod +x scripts/core/*.sh

./scripts/core/detect.sh > state/env.json
./scripts/core/apply.sh
./scripts/bootstrap-tools.sh
