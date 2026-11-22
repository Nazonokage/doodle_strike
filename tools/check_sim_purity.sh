#!/usr/bin/env bash
# Fails if packages/sim/lib contains anything that could break determinism or
# purity. Run in CI and before committing. See ARCHITECTURE.md section 4.3.
set -euo pipefail
cd "$(dirname "$0")/.."

banned='dart:math|dart:ui|dart:io|dart:isolate|package:flutter|package:flame|DateTime|Stopwatch|Random\(|\bsin\(|\bcos\(|\btan\(|\batan2\(|\bpow\(|\bexp\(|\blog\('

if grep -rEn "$banned" packages/sim/lib --include='*.dart'; then
  echo
  echo "FAIL: banned import or call found in packages/sim/lib (see lines above)."
  exit 1
fi
echo "sim purity check passed"
