#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/stage1_jailbreak.sh"
"$SCRIPT_DIR/stage2_sileo_openssh.sh"
