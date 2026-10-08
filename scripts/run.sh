#!/usr/bin/env bash
set -euo pipefail

# Interactive entrypoint. `docker compose up` (attached) can't forward
# stdin to a TUI — it only tails logs — so don't use it for emacs.
# If the `doom` service is already up (e.g. via `docker compose up -d`),
# exec into it; otherwise start a one-off interactive container.
if [ -n "$(docker compose ps -q doom 2>/dev/null)" ]; then
  docker compose exec doom emacs -nw "$@"
else
  docker compose run --rm doom emacs -nw "$@"
fi
