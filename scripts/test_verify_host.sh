#!/usr/bin/env bash
set -euo pipefail

skill_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
verify_script="$skill_dir/scripts/verify_host.sh"

bash -n "$verify_script"

output=$($verify_script)
for check in \
  'WSL runtime:' \
  'Codex CLI:' \
  'Docker socket access:' \
  'Unrestricted Codex policy:' \
  'Remote-control daemon:'; do
  grep -Fq "$check" <<<"$output"
done

if grep -Eq '/home/|gho_|ghp_|sk-[A-Za-z0-9]' <<<"$output"; then
  printf '%s\n' 'Verifier exposed sensitive output.' >&2
  exit 1
fi

printf '%s\n' 'verify_host.sh contract: PASS'
