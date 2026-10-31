#!/usr/bin/env bash
# Starts the local Firebase emulators for the driver app's `emulator` flavor:
# project demo-ctsgo-driver, every service on 127.0.0.1, the passenger repo's
# functions with payments stubbed. Refuses to start unless each check passes.
set -euo pipefail

PROJECT=demo-ctsgo-driver
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HERE/firebase.json"
FUNCTIONS="$(cd "$HERE/backend/functions" && pwd -P)"
NODE_BIN="${NODE_BIN:-$HOME/.nvm/versions/node/v22.23.3/bin}"
JAVA_HOME="${JAVA_HOME_21:-/usr/lib/jvm/java-21-openjdk-amd64}"

fail() { echo "start_emulators: $*" >&2; exit 1; }

# Toolchain: Node 22 (the functions' engine) with its firebase-tools; Java 21.
[ -x "$NODE_BIN/node" ] || fail "Node 22 not found at $NODE_BIN (set NODE_BIN)."
[ -x "$NODE_BIN/firebase" ] || fail "firebase-tools not installed for Node 22 ($NODE_BIN)."
[ -x "$JAVA_HOME/bin/java" ] || fail "Java 21 not found at $JAVA_HOME (set JAVA_HOME_21)."
export PATH="$NODE_BIN:$JAVA_HOME/bin:$PATH" JAVA_HOME

# Rules/functions watching polls instead of using inotify watches, which the
# IDE can exhaust (ENOSPC). Set CHOKIDAR_USEPOLLING=0 to use inotify.
export CHOKIDAR_USEPOLLING="${CHOKIDAR_USEPOLLING:-1}" CHOKIDAR_INTERVAL="${CHOKIDAR_INTERVAL:-2000}"

# The functions runtime's firebase-admin proxy drops admin.firestore.FieldValue
# and .Timestamp; the preload restores them (see admin_firestore_statics.js).
export CTS_FUNCTIONS_DIR="$FUNCTIONS"
export NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }--require $HERE/admin_firestore_statics.js"

# Payments: stub mode to a loopback gateway, fake secrets only.
ENV_LOCAL="$FUNCTIONS/.env.local"
SECRET_LOCAL="$FUNCTIONS/.secret.local"
[ -f "$ENV_LOCAL" ] || fail "$ENV_LOCAL is missing (copy .env.local.example)."
[ -f "$SECRET_LOCAL" ] || fail "$SECRET_LOCAL is missing (copy .secret.local.example; fake values only)."
grep -qx 'PAYMENTS_MODE=stub' "$ENV_LOCAL" || fail ".env.local must set PAYMENTS_MODE=stub."
grep -qE '^BRIDGE_API_BASE=http://(127\.0\.0\.1|localhost)(:[0-9]+)?(/|$)' "$ENV_LOCAL" \
  || fail ".env.local BRIDGE_API_BASE must be a loopback stub."
grep -qE '^BRIDGE_CALLBACK_BASE_URL=http://(127\.0\.0\.1|localhost)(:[0-9]+)?/' "$ENV_LOCAL" \
  || fail ".env.local BRIDGE_CALLBACK_BASE_URL must be loopback."
grep -qiE 'bridgeagw|cloudfunctions\.net|ctstransportapp' "$ENV_LOCAL" "$SECRET_LOCAL" \
  && fail ".env.local/.secret.local mention a production host or project."
# A project-specific env file for this project would override .env.local's intent.
[ -e "$FUNCTIONS/.env.$PROJECT" ] && fail "Unexpected $FUNCTIONS/.env.$PROJECT."

# No credentials: a demo- project needs none, and none may reach the emulators.
unset GOOGLE_APPLICATION_CREDENTIALS GOOGLE_CLOUD_PROJECT GCLOUD_PROJECT FIREBASE_TOKEN || true

# Every port free, so nothing else answers in an emulator's place.
for port in 9099 8080 9150 5001 9199 4400 4500 4000; do
  if ss -ltnH "( sport = :$port )" | grep -q .; then fail "port $port is already in use."; fi
done

grep -q '"singleProjectMode": true' "$CONFIG" || fail "singleProjectMode must be on."
if grep -E '"host"' "$CONFIG" | grep -vq '"127.0.0.1"'; then fail "every emulator must bind 127.0.0.1."; fi

echo "start_emulators: checks passed; project $PROJECT, functions $FUNCTIONS"
cd "$HERE"
exec firebase emulators:start --project "$PROJECT" --config "$CONFIG" "$@"
