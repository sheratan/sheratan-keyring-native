#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${TMPDIR:-/tmp}/keyring-security-checks"

cd "$ROOT_DIR"
swiftc \
  Sources/KeyringNative/Models/VaultModels.swift \
  Sources/KeyringNative/Services/CryptoService.swift \
  Sources/KeyringNative/Services/VaultFileService.swift \
  Sources/KeyringNative/Services/BackupService.swift \
  Tests/SecurityChecks.swift \
  -o "$OUTPUT"
"$OUTPUT"
