#!/usr/bin/env bash
set -euo pipefail

REPO="/home/sns-ansible/infra-ansible"
LOG="/home/sns-ansible/ansible-compose-refresh.log"

TO="cloud.status@sns.at,patrick.heichinger@sns.at,rubina.waldbauer@sns.at"
HOST="$(hostname -f 2>/dev/null || hostname)"
SUBJECT_OK="[ansible] compose refresh OK"
SUBJECT_BAD="[ansible] compose refresh ATTENTION"

# --- options ---
LIMIT_FLAG="--limit docker"
if [[ "${1:-}" == "--limit" && -n "${2:-}" ]]; then
  LIMIT_FLAG="--limit ${2}"
  shift 2
fi

if [[ "${1:-}" == "--test-mail" ]]; then
  echo "Test mail from ${HOST} at $(date -Is)" | mail -s "[ansible] TEST compose mail on ${HOST}" "$TO"
  exit 0
fi

cd "$REPO"

echo "===== $(date -Is) START compose refresh (${LIMIT_FLAG}) =====" | tee -a "$LOG"

set +e
/usr/bin/ansible-playbook -i inventory/hosts.ini playbooks/compose-refresh.yaml ${LIMIT_FLAG} 2>&1 \
  | awk '{ print strftime("%Y-%m-%dT%H:%M:%S%z"), $0 }' | tee -a "$LOG"
rc=${PIPESTATUS[0]}
set -e

echo "===== $(date -Is) END compose refresh (rc=$rc) =====" | tee -a "$LOG"

# --- signals / reporting ---
bad_markers="$(tail -n 2000 "$LOG" | egrep -n 'FAILED!|UNREACHABLE!|fatal:|ERROR!' | head -n 20 || true)"

# Optional: “did anything actually update?”
# (works well with docker compose pull output)
updates_markers="$(tail -n 4000 "$LOG" | egrep -n 'Downloaded newer image|Pull complete|Pulling|Recreating|Restarting' | head -n 50 || true)"

recap="$(
  awk '
    /PLAY RECAP/ { recap_on=1; buf="" }
    recap_on { buf = buf $0 "\n" }
    END { printf "%s", buf }
  ' "$LOG" | tail -n 60
)"

if [[ "$rc" -ne 0 || -n "$bad_markers" ]]; then
  {
    echo "Compose refresh needs attention on control host: $HOST"
    echo "Timestamp: $(date -Is)"
    echo
    echo "Playbook return code: $rc"
    echo
    if [[ -n "$bad_markers" ]]; then
      echo "Error markers (first 20):"
      echo "$bad_markers"
      echo
    fi
    echo "PLAY RECAP (last run):"
    echo "$recap"
    echo
    echo "Full log: $LOG"
  } | mail -s "$SUBJECT_BAD" "$TO"
else
  {
    echo "Compose refresh completed successfully on $HOST"
    echo "Timestamp: $(date -Is)"
    echo
    if [[ -n "$updates_markers" ]]; then
      echo "Update/recreate hints (best-effort):"
      echo "$updates_markers"
      echo
    else
      echo "No obvious image updates/recreates seen in output (likely no new digests)."
      echo
    fi
    echo "PLAY RECAP (last run):"
    echo "$recap"
    echo
    echo "Full log: $LOG"
  } | mail -s "$SUBJECT_OK" "$TO"
fi

exit "$rc"
