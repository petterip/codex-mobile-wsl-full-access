#!/usr/bin/env bash
set -euo pipefail

status() {
  local label="$1" result="$2"
  printf '%s: %s\n' "$label" "$result"
}

if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  status 'WSL runtime' PASS
else
  status 'WSL runtime' FAIL
fi

if command -v codex >/dev/null 2>&1; then
  status 'Codex CLI' PASS
else
  status 'Codex CLI' FAIL
fi

if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
  status 'Docker socket access' PASS
else
  status 'Docker socket access' FAIL
fi

config_file="${CODEX_HOME:-$HOME/.codex}/config.toml"
if [[ -f "$config_file" ]] \
  && grep -Eq '^approval_policy[[:space:]]*=[[:space:]]*"never"' "$config_file" \
  && grep -Eq '^sandbox_mode[[:space:]]*=[[:space:]]*"danger-full-access"' "$config_file"; then
  status 'Unrestricted Codex policy' PASS
else
  status 'Unrestricted Codex policy' FAIL
fi

if command -v codex >/dev/null 2>&1 \
  && codex app-server daemon version 2>/dev/null | grep -q '"status":"running"'; then
  status 'Remote-control daemon' PASS
else
  status 'Remote-control daemon' FAIL
fi
