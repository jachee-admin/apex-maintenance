#!/usr/bin/env bash
set -euo pipefail
DATE_TAG="${1:-$(date +%Y%m%d_%H%M%S)}"
SQLPLUS="${SQLPLUS:-sqlplus}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIAG="$DIR/../sql/diagnostics/run_all_diagnostics.sql"
$SQLPLUS / as sysdba @"$DIAG" _date="$DATE_TAG"
echo "Diagnostics complete. See diag_report_${DATE_TAG}.log"

