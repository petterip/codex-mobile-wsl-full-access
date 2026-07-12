#!/usr/bin/env bash
set -euo pipefail

action="${1:---check}"
case "$action" in
  --check|--install|--update|--uninstall) ;;
  *)
    printf 'Usage: %s [--check|--install|--update|--uninstall]\n' "${0##*/}" >&2
    exit 64
    ;;
esac

source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
target_dir="${CODEX_HOME:-$HOME/.codex}/skills/codex-mobile-wsl-full-access"
target_skill="$target_dir/SKILL.md"

is_our_skill() {
  [[ -f "$target_skill" ]] && grep -Fqx 'name: codex-mobile-wsl-full-access' "$target_skill"
}

case "$action" in
  --check)
    if is_our_skill; then
      printf 'Installed skill: PASS (%s)\n' "$target_dir"
    else
      printf 'Installed skill: FAIL (%s)\n' "$target_dir" >&2
      exit 1
    fi
    ;;
  --install)
    if [[ -e "$target_dir" ]]; then
      printf 'Refusing to replace existing path: %s\nUse --update only for this skill.\n' "$target_dir" >&2
      exit 1
    fi
    mkdir -p "$(dirname "$target_dir")"
    cp -a "$source_dir" "$target_dir"
    printf 'Installed skill: PASS (%s)\n' "$target_dir"
    ;;
  --update)
    if ! is_our_skill; then
      printf 'Refusing to update a missing or different skill: %s\n' "$target_dir" >&2
      exit 1
    fi
    cp -a "$source_dir/." "$target_dir/"
    printf 'Updated skill: PASS (%s)\n' "$target_dir"
    ;;
  --uninstall)
    if ! is_our_skill; then
      printf 'Refusing to remove a missing or different skill: %s\n' "$target_dir" >&2
      exit 1
    fi
    rm -rf "$target_dir"
    printf 'Removed skill: PASS (%s)\n' "$target_dir"
    ;;
esac
