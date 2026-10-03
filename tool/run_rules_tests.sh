#!/usr/bin/env bash
#
# Runs the Firestore security-rules test suite against the emulator.
#
# The emulator is what makes the negative assertions possible: the production
# project cannot be used to prove that a rule *blocks* something, because a
# blocked request there is indistinguishable from a bug in the test.
#
# Usage: ./tool/run_rules_tests.sh

set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT_ID="padma-cb65f"

# The Firestore emulator requires Java 21+, but the system default on many
# machines is still 17. Prefer a modern JDK if one is installed, and only fall
# back to whatever `java` resolves to.
#
# `java -version` prints e.g. `openjdk version "25.0.2" 2026-01-20`, so the
# major version is the first number inside the quotes.
jdk_major() {
  "$1" -version 2>&1 |
    head -1 |
    sed -E 's/.*version "([0-9]+).*/\1/'
}

for candidate in \
  /opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home \
  /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
  "$(/usr/libexec/java_home -v 25 2>/dev/null)" \
  "$(/usr/libexec/java_home -v 21 2>/dev/null)"
do
  [ -n "$candidate" ] || continue
  if [ -x "$candidate/bin/java" ] && [ "$(jdk_major "$candidate/bin/java")" -ge 21 ] 2>/dev/null; then
    export JAVA_HOME="$candidate"
    export PATH="$JAVA_HOME/bin:$PATH"
    echo "Using JDK $("$JAVA_HOME/bin/java" -version 2>&1 | head -1)"
    break
  fi
done

if [ "$(jdk_major java)" -lt 21 ] 2>/dev/null; then
  echo "ERROR: the Firestore emulator needs Java 21+."
  echo "       Current: $(java -version 2>&1 | head -1)"
  echo "       Install one, e.g. brew install openjdk@25"
  exit 1
fi

if [ ! -d tool/node_modules ]; then
  echo "Installing rules-test dependencies..."
  npm --prefix tool install --silent
fi

# A stale emulator holding the old rules would silently pass or fail wrongly.
echo "Ensuring no emulator is already running on :8080..."
lsof -ti tcp:8080 | xargs kill -9 2>/dev/null || true

echo "Starting Firestore emulator..."
firebase emulators:start \
  --only firestore \
  --project "$PROJECT_ID" \
  >tool/.emulator.log 2>&1 &

EMULATOR_PID=$!

# Stop the emulator on exit, however we exit.
cleanup() {
  echo
  echo "Stopping emulator..."
  kill "$EMULATOR_PID" 2>/dev/null || true
  wait "$EMULATOR_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Poll until the emulator answers, rather than sleeping a fixed amount.
echo "Waiting for the emulator to be ready..."
for _ in $(seq 1 60); do
  if curl -s "http://127.0.0.1:8080" >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$EMULATOR_PID" 2>/dev/null; then
    echo "Emulator failed to start. Last 30 lines:"
    tail -30 tool/.emulator.log
    exit 1
  fi
  sleep 1
done

# The emulator rewrites these to its own config on boot.
export FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
export GCLOUD_PROJECT="$PROJECT_ID"

node tool/firestore_rules_test.js
