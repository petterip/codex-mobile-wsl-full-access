---
name: codex-mobile-wsl-full-access
description: Configure and verify ChatGPT/Codex mobile remote control of a Windows WSL2 host with unrestricted command execution, including Docker. Use when a user wants mobile Codex to control a WSL host, eliminate command approval prompts, or diagnose mobile/WSL permission mismatches.
---

# Codex Mobile WSL Full Access

Configure this workflow deterministically. Do not ask the user to run terminal commands that the agent can run. Do not expose, save, or publish usernames, hostnames, absolute paths, pairing codes, auth material, session logs, Docker container names, or repository contents.

## 1. Request Desktop Action

Ask the user to complete these actions in the Windows Codex desktop app, then wait for confirmation:

1. Open **Settings** and set **Agent environment** to **WSL**.
2. Restart the desktop app. The agent-environment change is not active until restart.

Do not ask the user to alter `CODEX_HOME`, create wrappers, or copy session files unless direct evidence shows the default WSL setup cannot start the daemon.

## 2. Pair Mobile

Check the daemon first:

```bash
codex app-server daemon version
```

Start remote control only when it is not already running:

```bash
codex remote-control start
```

If the user reports that the device is not paired, generate a short-lived pairing code:

```bash
codex remote-control pair
```

Ask the user to complete only the mobile pairing screen. Never repeat a pairing code in logs, summaries, commits, or published files.

## 3. Request Mobile Permission Selection

Ask the user to open the connected host's composer permission picker in the ChatGPT mobile app and select **Full access**. This is the mobile execution policy that permits unrestricted commands. Do not recommend `Custom (config.toml)` unless the user explicitly asks to use a custom profile.

Ask the user to start a new remote task only if the current task was created before selecting **Full access**.

## 4. Apply and Verify Host Policy

For the requested unrestricted setup, ensure the WSL Codex home config contains:

```toml
approval_policy = "never"
sandbox_mode = "danger-full-access"
```

Preserve unrelated configuration. Restart the managed app-server only if either setting changed:

```bash
codex app-server daemon restart
```

Run `scripts/verify_host.sh`. If Docker access fails, diagnose socket ownership and group membership and apply the required host-side fix directly. Ask the user only when their password or a Windows/Docker Desktop UI action is required.

## 5. Verify End to End

Run these commands in the active mobile-controlled thread:

```bash
docker ps >/dev/null && printf 'docker ps: PASS\n'
docker info >/dev/null && printf 'docker info: PASS\n'
```

Success requires both commands to finish and no mobile approval card to appear. Ask the user only whether an approval card appeared. If it did, stop and inspect the active session policy before changing any configuration.

## Completion Report

Report only:

- desktop agent environment is WSL
- mobile permission mode is Full access
- managed remote daemon is running
- Docker end-to-end check passed without approval

Do not include personal or machine-specific information.
