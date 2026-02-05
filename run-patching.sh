#!/usr/bin/env bash
set -euo pipefail

REPO="/home/sns-ansible/infra-ansible"
LOG="/home/sns-ansible/ansible-patching.log"

TO="cloud.status@sns.at,patrick.heichinger@sns.at,rubina.waldbauer@sns.at"
HOST="$(hostname -f 2>/dev/null || hostname)"
SUBJECT_OK="[ansible] patching OK"
SUBJECT_BAD="[ansible] patching ATTENTION"

# --- options ---
CHECK_FLAG=""
if [[ "${1:-}" == "--check" ]]; then
  CHECK_FLAG="--check"
  shift
fi

if [[ "${1:-}" == "--test-mail" ]]; then
  echo "Test mail from ${HOST} at $(date -Is)" | mail -s "[ansible] TEST mail on ${HOST}" "$TO"
  exit 0
fi

cd "$REPO"

echo "===== $(date -Is) START patching ${CHECK_FLAG:+(CHECK MODE)} =====" | tee -a "$LOG"

# Run playbook, timestamp each output line, and capture real return code
set +e
/usr/bin/ansible-playbook -i inventory/hosts.ini playbooks/patching.yaml ${CHECK_FLAG} 2>&1 \
  | awk '{ print strftime("%Y-%m-%dT%H:%M:%S%z"), $0 }' | tee -a "$LOG"
rc=${PIPESTATUS[0]}
set -e

echo "===== $(date -Is) END patching (rc=$rc) =====" | tee -a "$LOG"

# --- signals / reporting ---
# Look for obvious failure markers in recent log tail
bad_markers="$(tail -n 2000 "$LOG" | egrep -n 'FAILED!|UNREACHABLE!|fatal:|ERROR!' | head -n 20 || true)"

# Check reboot-required on any host (useful if patching ran without reboot, or reboot still needed)
need_reboot_hosts="$(
  /usr/bin/ansible all -i inventory/hosts.ini -m stat -a 'path=/var/run/reboot-required' 2>/dev/null \
  | awk '
      /^[^ ]+ \|/ { host=$1 }
      /"exists": true/ { print host }
    ' | sort -u
)"

recap="$(
  awk '
    /PLAY RECAP/ { recap_on=1; buf="" }
    recap_on { buf = buf $0 "\n" }
    END { printf "%s", buf }
  ' "$LOG" | tail -n 60
)"


if [[ "$rc" -ne 0 || -n "$bad_markers" || -n "$need_reboot_hosts" ]]; then
  {
    echo "Ansible patching needs attention on control host: $HOST"
    echo "Timestamp: $(date -Is)"
    echo
    echo "Playbook return code: $rc"
    echo
    if [[ -n "$need_reboot_hosts" ]]; then
      echo "Reboot still required on these hosts:"
      echo "$need_reboot_hosts"
      echo
    fi
    if [[ -n "$bad_markers" ]]; then
      echo "Error markers found (line numbers relative to log tail):"
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
    echo "Patching completed successfully on $HOST"
    echo "Timestamp: $(date -Is)"
    echo
    echo "PLAY RECAP (last run):"
    echo "$recap"
    echo
    echo "Full log: $LOG"
  } | mail -s "$SUBJECT_OK" "$TO"
fi

exit "$rc"

