#!/bin/sh
set -euo pipefail

PROBE="${1:-health}"
PORT="${SILVERBULLET_PORT:-3000}"
HOST="${SILVERBULLET_HEALTH_HOST:-127.0.0.1}"
URL="http://${HOST}:${PORT}/"

if ! command -v silverbullet >/dev/null 2>&1; then
  echo "silverbullet binary missing" >&2
  exit 1
fi

case "${PROBE}" in
  test)
    /usr/local/bin/silverbullet version >/dev/null 2>&1 || exit 1
    ;;
  startup)
    # Give the application a few seconds to bind the port during cold start.
    sleep 2
    ;;
  *)
    ;;
esac

curl --fail --silent --show-error --max-time 5 "${URL}" >/dev/null
