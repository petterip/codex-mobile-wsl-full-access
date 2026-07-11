#!/usr/bin/env bash
set -euo pipefail

skill_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
verify_script="$skill_dir/scripts/verify_host.sh"
skill_file="$skill_dir/SKILL.md"

bash -n "$verify_script"

output=$($verify_script)
for check in \
  'WSL runtime:' \
  'Codex CLI:' \
  'Docker socket access:' \
  'Unrestricted Codex policy:' \
  'Managed app-server daemon:' \
  'Remote-control process:'; do
  grep -Fq "$check" <<<"$output"
done

grep -Fq 'set **Agent environment** to **WSL**' "$skill_file"
grep -Fq 'select **Full access**' "$skill_file"
grep -Fq 'codex remote-control start' "$skill_file"
grep -Fq 'Do not use the Codex Desktop restart control' "$skill_file"
if grep -Fq 'Integrated terminal' "$skill_file" \
  || grep -Fq 'explicitly confirms' "$skill_file"; then
  printf '%s\n' 'Skill contains an unnecessary user confirmation step.' >&2
  exit 1
fi

printf '%s\n' 'verify_host.sh contract: PASS'
