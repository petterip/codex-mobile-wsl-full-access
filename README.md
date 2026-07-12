# Codex Mobile WSL Full Access

This repository contains the `codex-mobile-wsl-full-access` skill for configuring and checking a Windows WSL2 host used through Codex mobile remote control.

## Install

Clone this repository, then install the skill into the Codex home used by WSL:

```bash
bash skills/codex-mobile-wsl-full-access/scripts/install.sh --check
bash skills/codex-mobile-wsl-full-access/scripts/install.sh --install
```

Use `--update` to replace an installed copy from this checkout. `--uninstall` only removes a destination that still identifies itself as this skill. Set `CODEX_HOME` to target a non-default Codex home.

## Verify

```bash
bash skills/codex-mobile-wsl-full-access/scripts/verify_host.sh
```

The default command and `--json` exit non-zero if a required host prerequisite is unavailable. Use `--report` for non-failing diagnostics. Mobile pairing and approval-free execution are intentionally not inferred from a local process; verify them in the active mobile thread.

## Compatibility

Required: WSL2, Bash 4+, Perl, GNU `timeout`, Codex CLI with `remote-control`, and Docker CLI. Python 3.11+ enables the full TOML parser; older Python uses a deliberately narrow parser for the two root policy fields. Docker Desktop must expose a usable WSL socket. The skill does not assume a specific Windows path or a particular desktop-app version.
