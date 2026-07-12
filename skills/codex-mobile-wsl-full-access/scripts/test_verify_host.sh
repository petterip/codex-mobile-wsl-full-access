#!/usr/bin/env bash
set -euo pipefail

skill_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
verify_script="$skill_dir/scripts/verify_host.sh"
install_script="$skill_dir/scripts/install.sh"
skill_file="$skill_dir/SKILL.md"

bash -n "$verify_script"
bash -n "$install_script"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin"
printf '6.6.0-microsoft-standard-WSL2\n' >"$fixture/osrelease"
cat >"$fixture/config.toml" <<'EOF'
approval_policy = "never"
sandbox_mode = "danger-full-access"
EOF

cat >"$fixture/bin/codex" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == remote-control && "$2" == --help ]]; then
  printf 'Commands:\n  start\n'
elif [[ "$1" == app-server && "$2" == daemon && "$3" == version ]]; then
  printf '{"status":"running"}\n'
else
  exit 2
fi
EOF
cat >"$fixture/bin/docker" <<'EOF'
#!/usr/bin/env bash
if [[ "${VERIFY_TEST_DOCKER_SLEEP:-}" == true ]]; then
  sleep 2
fi
[[ "$1" == ps ]]
EOF
cat >"$fixture/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fixture/bin/codex" "$fixture/bin/docker" "$fixture/bin/pgrep"

output=$(PATH="$fixture/bin:$PATH" VERIFY_OSRELEASE_FILE="$fixture/osrelease" VERIFY_CONFIG_FILE="$fixture/config.toml" bash "$verify_script")
grep -Fq 'Docker socket access: PASS' <<<"$output"
grep -Fq 'Remote-control process configuration: PASS' <<<"$output"
grep -Fq 'Mobile pairing and approval-free execution: UNKNOWN' <<<"$output"

timeout_report=$(PATH="$fixture/bin:$PATH" VERIFY_OSRELEASE_FILE="$fixture/osrelease" VERIFY_CONFIG_FILE="$fixture/config.toml" VERIFY_TEST_DOCKER_SLEEP=true VERIFY_TIMEOUT_SECONDS=1 bash "$verify_script" --report)
grep -Fq 'Docker socket access: FAIL (docker-ps-timed-out)' <<<"$timeout_report"

printf 'approval_policy = "on-request"\n' >"$fixture/config.toml"
if PATH="$fixture/bin:$PATH" VERIFY_OSRELEASE_FILE="$fixture/osrelease" VERIFY_CONFIG_FILE="$fixture/config.toml" bash "$verify_script" >/dev/null; then
  printf '%s\n' 'Strict verification passed with an invalid policy.' >&2
  exit 1
fi
report=$(PATH="$fixture/bin:$PATH" VERIFY_OSRELEASE_FILE="$fixture/osrelease" VERIFY_CONFIG_FILE="$fixture/config.toml" bash "$verify_script" --report)
grep -Fq 'Unrestricted Codex policy: FAIL' <<<"$report"
if json=$(PATH="$fixture/bin:$PATH" VERIFY_OSRELEASE_FILE="$fixture/osrelease" VERIFY_CONFIG_FILE="$fixture/config.toml" bash "$verify_script" --json); then
  printf '%s\n' 'JSON verification passed with an invalid policy.' >&2
  exit 1
fi
grep -Fq '"ok":false' <<<"$json"

grep -Fq 'select **Full access**' "$skill_file"
grep -Fq 'codex remote-control start' "$skill_file"
grep -Fq 'Mobile pairing and approval-free execution' "$skill_file"

install_home="$fixture/codex-home"
if CODEX_HOME="$install_home" bash "$install_script" --check >/dev/null 2>&1; then
  printf '%s\n' 'Installer check passed before installation.' >&2
  exit 1
fi
CODEX_HOME="$install_home" bash "$install_script" --install >/dev/null
CODEX_HOME="$install_home" bash "$install_script" --check >/dev/null
CODEX_HOME="$install_home" bash "$install_script" --update >/dev/null
CODEX_HOME="$install_home" bash "$install_script" --uninstall >/dev/null
if [[ -e "$install_home/skills/codex-mobile-wsl-full-access" ]]; then
  printf '%s\n' 'Installer uninstall left the target behind.' >&2
  exit 1
fi

printf '%s\n' 'verify_host.sh hermetic contract: PASS'
