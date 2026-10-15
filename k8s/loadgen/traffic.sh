#!/bin/sh
# Continuous, shaped traffic for the POC sandbox.
#
# Most iterations are ordinary reads. Every Nth iteration adds one of the
# deliberate-misbehaviour endpoints, so there is a steady trickle of slow
# requests, chatty query patterns, full table scans and 5xx responses to look at
# without anyone having to click around.
#
# Everything is || true: a failing request is often the point, and the loop must
# never exit.

WEB="${WEB_URL:-http://phr-web}"
API="${API_URL:-http://phr-api:3000}"
INTERVAL="${INTERVAL_SECONDS:-3}"
SLOW_EVERY="${SLOW_EVERY:-8}"
ERROR_EVERY="${ERROR_EVERY:-11}"
HEAVY_EVERY="${HEAVY_EVERY:-13}"
WRITE_EVERY="${WRITE_EVERY:-5}"

hit() {
  # $1 = label, rest = curl args
  label="$1"; shift
  code=$(curl -sS -o /dev/null -m 30 -w '%{http_code} %{time_total}' "$@" 2>/dev/null) || code="--- ---"
  echo "$(date -u +%H:%M:%S) ${label} ${code}"
}

echo "loadgen starting: web=${WEB} api=${API} interval=${INTERVAL}s"

i=0
while true; do
  i=$((i + 1))
  id=$(( (i % 120) + 1 ))

  # --- steady-state reads through the front end ---
  hit "GET  web /"                     "${WEB}/"
  hit "GET  web /customers"            "${WEB}/customers"
  hit "GET  web /customers/${id}"      "${WEB}/customers/${id}"
  hit "GET  web /projects"             "${WEB}/projects?status=in_progress"
  hit "GET  web /leads"                "${WEB}/leads"
  hit "GET  web /appointments"         "${WEB}/appointments?status=scheduled"

  # --- steady-state reads straight against the API ---
  hit "GET  api /leads"                "${API}/api/v1/leads?per_page=25"
  hit "GET  api /leads/stats"          "${API}/api/v1/leads/stats"
  hit "GET  api /appointments"         "${API}/api/v1/appointments?per_page=25"

  # --- writes: creates a lead, then Sidekiq scores it ---
  if [ $((i % WRITE_EVERY)) -eq 0 ]; then
    hit "POST web /internal/leads" -X POST -H 'Content-Type: application/json' "${WEB}/internal/leads"
  fi

  # --- slow: one app-side sleep, one database-side sleep ---
  if [ $((i % SLOW_EVERY)) -eq 0 ]; then
    hit "GET  web /debug/slow"         "${WEB}/debug/slow?seconds=3"
    hit "GET  api /simulate/slow_query" "${API}/api/v1/simulate/slow_query?seconds=2"
  fi

  # --- heavy: N+1 patterns, full table scan, CPU burn ---
  if [ $((i % HEAVY_EVERY)) -eq 0 ]; then
    hit "GET  web /debug/n_plus_one"   "${WEB}/debug/n_plus_one?limit=100"
    hit "GET  api /simulate/n_plus_one" "${API}/api/v1/simulate/n_plus_one?limit=100"
    hit "GET  api /simulate/table_scan" "${API}/api/v1/simulate/table_scan?term=roof"
    hit "GET  api /simulate/cpu"        "${API}/api/v1/simulate/cpu?ms=800"
  fi

  # --- failures: one raised in the front end, one propagated from the API ---
  if [ $((i % ERROR_EVERY)) -eq 0 ]; then
    hit "GET  web /debug/error"        "${WEB}/debug/error"
    hit "GET  web /debug/downstream"   "${WEB}/debug/downstream?mode=error"
    hit "GET  api /simulate/error"     "${API}/api/v1/simulate/error"
  fi

  sleep "$INTERVAL"
done
