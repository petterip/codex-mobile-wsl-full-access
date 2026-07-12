#!/usr/bin/env bash
set -euo pipefail

# Verify the host-side prerequisites only. Mobile permission selection and an
# approval-free command must be confirmed in the active mobile thread.

mode=strict
case "${1:-}" in
  '') ;;
  --report) mode=report ;;
  --json) mode=json ;;
  *)
    printf 'Usage: %s [--report|--json]\n' "${0##*/}" >&2
    exit 64
    ;;
esac

timeout_seconds="${VERIFY_TIMEOUT_SECONDS:-8}"
if ! [[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || (( timeout_seconds > 60 )); then
  printf 'VERIFY_TIMEOUT_SECONDS must be an integer from 1 through 60.\n' >&2
  exit 64
fi

declare -a labels results reasons required
failed_required=0

status() {
  local label="$1" result="$2" reason="$3" is_required="$4"
  labels+=("$label")
  results+=("$result")
  reasons+=("$reason")
  required+=("$is_required")
  if [[ "$is_required" == true && "$result" != PASS ]]; then
    failed_required=1
  fi
  if [[ "$mode" != json ]]; then
    printf '%s: %s (%s)\n' "$label" "$result" "$reason"
  fi
}

run_bounded() {
  command -v timeout >/dev/null 2>&1 || return 125
  timeout --foreground "${timeout_seconds}s" "$@"
}

osrelease_file="${VERIFY_OSRELEASE_FILE:-/proc/sys/kernel/osrelease}"
if [[ -r "$osrelease_file" ]] && grep -qi microsoft "$osrelease_file"; then
  status 'WSL runtime' PASS detected true
else
  status 'WSL runtime' FAIL not-wsl true
fi

if command -v codex >/dev/null 2>&1; then
  status 'Codex CLI' PASS detected true
  if codex remote-control --help 2>/dev/null | grep -Fq 'start'; then
    status 'Remote-control CLI capability' PASS supported true
  else
    status 'Remote-control CLI capability' FAIL unsupported true
  fi
else
  status 'Codex CLI' FAIL missing true
  status 'Remote-control CLI capability' FAIL codex-missing true
fi

if command -v timeout >/dev/null 2>&1; then
  status 'Bounded command support' PASS detected true
else
  status 'Bounded command support' FAIL timeout-missing true
fi

if command -v docker >/dev/null 2>&1; then
  status 'Docker CLI' PASS detected true
  if run_bounded docker ps >/dev/null 2>&1; then
    status 'Docker socket access' PASS docker-ps-succeeded true
  else
    docker_exit=$?
    if [[ "$docker_exit" == 124 ]]; then
      status 'Docker socket access' FAIL docker-ps-timed-out true
    elif [[ "$docker_exit" == 125 ]]; then
      status 'Docker socket access' FAIL timeout-missing true
    else
      status 'Docker socket access' FAIL docker-ps-failed true
    fi
  fi
else
  status 'Docker CLI' FAIL missing true
  status 'Docker socket access' FAIL docker-missing true
fi

config_file="${VERIFY_CONFIG_FILE:-${CODEX_HOME:-$HOME/.codex}/config.toml}"
config_has_unrestricted_policy() {
  local file="$1"
  if python3 -c 'import tomllib' >/dev/null 2>&1 && python3 - "$file" <<'PY' >/dev/null 2>&1
import sys
import tomllib

with open(sys.argv[1], 'rb') as config:
    values = tomllib.load(config)

if values.get('approval_policy') != 'never':
    raise SystemExit(1)
if values.get('sandbox_mode') != 'danger-full-access':
    raise SystemExit(1)
PY
  then
    return
  fi

  # Python <3.11 has no standard TOML parser. This fallback intentionally
  # accepts only the two root-level, basic-string assignments this skill needs.
  perl - "$file" <<'PERL'
use strict;
use warnings;
my %values;
my $in_table = 0;
while (<>) {
  next if /^\s*(?:#|$)/;
  if (/^\s*\[/) { $in_table = 1; next; }
  next if $in_table;
  if (/^\s*(approval_policy|sandbox_mode)\s*=\s*"([^"\\]*)"\s*(?:#.*)?$/) {
    exit 1 if exists $values{$1};
    $values{$1} = $2;
  }
}
exit (($values{approval_policy} // '') ne 'never'
  || ($values{sandbox_mode} // '') ne 'danger-full-access');
PERL
}

if [[ ! -f "$config_file" ]]; then
  status 'Unrestricted Codex policy' FAIL config-missing true
elif config_has_unrestricted_policy "$config_file"; then
  status 'Unrestricted Codex policy' PASS config-policy-matches true
else
  status 'Unrestricted Codex policy' FAIL config-policy-mismatch-or-invalid true
fi

if command -v codex >/dev/null 2>&1 && run_bounded codex app-server daemon version 2>/dev/null | grep -Fq '"status":"running"'; then
  status 'Managed app-server daemon' PASS daemon-running true
else
  daemon_exit=${PIPESTATUS[0]:-1}
  if [[ "$daemon_exit" == 124 ]]; then
    status 'Managed app-server daemon' FAIL daemon-version-timed-out true
  else
    status 'Managed app-server daemon' FAIL daemon-not-running true
  fi
fi

# The CLI exposes no remote-control readiness endpoint. Process inspection is
# deliberately reported as process configuration, not mobile connectivity.
if pgrep -f -- 'codex app-server --remote-control' >/dev/null 2>&1; then
  status 'Remote-control process configuration' PASS process-argument-present true
else
  status 'Remote-control process configuration' FAIL remote-control-process-missing true
fi
status 'Mobile pairing and approval-free execution' UNKNOWN requires-active-mobile-thread false

if [[ "$mode" == json ]]; then
  printf '{"checks":['
  for index in "${!labels[@]}"; do
    (( index > 0 )) && printf ','
    printf '{"label":"%s","result":"%s","reason":"%s","required":%s}' \
      "${labels[$index]}" "${results[$index]}" "${reasons[$index]}" "${required[$index]}"
  done
  printf '],"ok":%s}\n' "$([[ "$failed_required" == 0 ]] && printf true || printf false)"
fi

if [[ "$mode" != report && "$failed_required" != 0 ]]; then
  exit 1
fi
