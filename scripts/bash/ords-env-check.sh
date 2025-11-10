#!/usr/bin/env bash
set -euo pipefail
echo "=== Host/Env ==="
uname -a || true
echo "JAVA_HOME: ${JAVA_HOME:-}"
echo "ORACLE_HOME: ${ORACLE_HOME:-}"
echo "NLS_LANG: ${NLS_LANG:-}"
echo "PATH (first 5):"; echo "$PATH" | tr ':' '\n' | head -5

echo; echo "=== Which sqlplus ==="
command -v sqlplus || true
ls -l "$(command -v sqlplus 2>/dev/null)" || true

echo; echo "=== ORDS version/config ==="
ords --version || true
ords --config "${ORDS_CONFIG:-$HOME/ords/config}" config list || true

echo; echo "Tip: ensure db.serviceName points to the PDB service, not CDB$ROOT."

