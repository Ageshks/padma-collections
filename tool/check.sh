#!/usr/bin/env bash
# Padma Collections — quality gate.
#
# Runs formatting, static analysis and the test suite in one command so
# regressions are caught before they reach a device.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

echo "==> Formatting"
dart format lib test --line-length 80 >/dev/null 2>&1

echo "==> Static analysis"
ANALYSIS=$(dart analyze 2>&1)
# `info` lints are advisory; only errors and warnings fail the gate.
PROBLEMS=$(echo "$ANALYSIS" | grep -E '^\s+(error|warning)\s+-' || true)
if [ -n "$PROBLEMS" ]; then
  echo "$PROBLEMS"
  echo ""
  echo "ANALYSIS FAILED — fix the errors/warnings above."
  exit 1
fi

echo "    no errors or warnings"

echo "==> Tests"
if ! flutter test --reporter failures-only 2>&1 | tail -8; then
  echo ""
  echo "TESTS FAILED"
  exit 1
fi

echo ""
echo "All checks passed."