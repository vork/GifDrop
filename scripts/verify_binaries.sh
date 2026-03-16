#!/usr/bin/env bash
# verify_binaries.sh — Verify bundled ffmpeg/libgifski binaries.
#
# Usage:
#   ./scripts/verify_binaries.sh <dir-containing-binaries> [checksums.sha256]
#
# What it does:
#   1. Checks that ffmpeg and libgifski exist
#   2. Prints version/type output for each
#   3. Computes SHA256 and optionally compares against a checksums file
#   4. Reports PASS / FAIL

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

BIN_DIR="${1:?Usage: $0 <binary-dir> [checksums.sha256]}"
CHECKSUMS_FILE="${2:-}"

PASS=true

# Determine binary names based on OS
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
  FFMPEG="ffmpeg.exe"
  GIFSKI_LIB="gifski.dll"
else
  FFMPEG="ffmpeg"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    GIFSKI_LIB="libgifski.dylib"
  else
    GIFSKI_LIB="libgifski.so"
  fi
fi

echo "=== Verifying binaries in ${BIN_DIR} ==="
echo ""

# ── Existence ──────────────────────────────────────────────────────
for bin in "$FFMPEG" "$GIFSKI_LIB"; do
  path="${BIN_DIR}/${bin}"
  if [[ ! -f "$path" ]]; then
    echo -e "${RED}FAIL${NC}: ${bin} not found at ${path}"
    PASS=false
    continue
  fi
  echo -e "${GREEN}  OK${NC}: ${bin} found"
done

echo ""

# ── Version / type output ─────────────────────────────────────────
echo "--- ffmpeg version ---"
if [[ -x "${BIN_DIR}/${FFMPEG}" ]]; then
  "${BIN_DIR}/${FFMPEG}" -version 2>&1 | head -3 || { echo -e "${RED}FAIL${NC}: could not run ffmpeg"; PASS=false; }
else
  echo -e "${RED}FAIL${NC}: ffmpeg not executable"
  PASS=false
fi

echo ""
echo "--- libgifski type ---"
if [[ -f "${BIN_DIR}/${GIFSKI_LIB}" ]]; then
  file "${BIN_DIR}/${GIFSKI_LIB}"
else
  echo -e "${RED}FAIL${NC}: libgifski not found"
  PASS=false
fi

echo ""

# ── SHA256 ─────────────────────────────────────────────────────────
echo "--- SHA256 hashes ---"
SHASUM_CMD="shasum -a 256"
command -v sha256sum >/dev/null 2>&1 && SHASUM_CMD="sha256sum"

for bin in "$FFMPEG" "$GIFSKI_LIB"; do
  path="${BIN_DIR}/${bin}"
  [[ -f "$path" ]] && $SHASUM_CMD "$path"
done

echo ""

# ── Compare against provided checksums ─────────────────────────────
if [[ -n "$CHECKSUMS_FILE" && -f "$CHECKSUMS_FILE" ]]; then
  echo "--- Comparing against ${CHECKSUMS_FILE} ---"
  pushd "$BIN_DIR" >/dev/null
  if $SHASUM_CMD -c "$CHECKSUMS_FILE"; then
    echo -e "${GREEN}  OK${NC}: All checksums match"
  else
    echo -e "${RED}FAIL${NC}: Checksum mismatch!"
    PASS=false
  fi
  popd >/dev/null
elif [[ -n "$CHECKSUMS_FILE" ]]; then
  echo -e "${YELLOW}WARN${NC}: Checksums file not found: ${CHECKSUMS_FILE}"
fi

echo ""

# ── Result ─────────────────────────────────────────────────────────
if $PASS; then
  echo -e "${GREEN}=== ALL CHECKS PASSED ===${NC}"
  exit 0
else
  echo -e "${RED}=== SOME CHECKS FAILED ===${NC}"
  exit 1
fi
