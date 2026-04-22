#!/usr/bin/env bash
# setup-caffeinate-launchd.sh — Install/uninstall caffeinate LaunchAgent (Phase 1.5).
#
# Keeps the Mac awake 24/7 so iPhone SSH/mosh sessions don't drop when the
# Mac would otherwise sleep. Uses /usr/bin/caffeinate -i -m -s (idle + disk +
# system sleep blocked; system-sleep block is AC-only per Apple spec).
#
# HARD-GATE #1: default dry-run. --apply required to load the agent.
# Idempotent: safe to re-run; reloads existing agent cleanly.
# Requires macOS 13 (Ventura) or later — uses `launchctl bootstrap`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/../templates/com.mobile-dev-bridge.caffeinate.plist.template"
LABEL="com.mobile-dev-bridge.caffeinate"
PLIST_TARGET="${HOME}/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="${HOME}/Library/Logs"

ACTION="dry-run"
for arg in "$@"; do
  case "${arg}" in
    --apply)     ACTION="apply" ;;
    --uninstall) ACTION="uninstall" ;;
    --status)    ACTION="status" ;;
    --help|-h)
      cat <<USAGE
Usage: setup-caffeinate-launchd.sh [--apply|--uninstall|--status]

  (no flag)     Dry-run. Prints planned actions. No changes to system.
  --apply       Install and load the LaunchAgent (idempotent).
  --uninstall   Unload and remove the LaunchAgent.
  --status      Show current LaunchAgent and plist state.

Installs ~/Library/LaunchAgents/${LABEL}.plist that runs
  /usr/bin/caffeinate -i -m -s
as a long-lived background service so the Mac stays awake 24/7.
Requires macOS 13+ (uses launchctl bootstrap/bootout subcommands).

See references/setup-tier1.md §8 for lid-closed / Apple Silicon caveats
(caffeinate does NOT override hardware lid-magnet sleep on Apple Silicon).
USAGE
      exit 0 ;;
    *)
      printf '[setup-caffeinate][ERROR] Unknown arg: %s\n' "${arg}" >&2
      exit 2 ;;
  esac
done

log()    { printf '[setup-caffeinate] %s\n' "$*"; }
dryrun() { printf '[setup-caffeinate][DRY-RUN] Would run: %s\n' "$*"; }
fail()   { printf '[setup-caffeinate][ERROR] %s\n' "$*" >&2; exit 1; }

# ──────────────────────────────────────────────────────────────────────────
# Preflight
# ──────────────────────────────────────────────────────────────────────────
if [ "$(uname -s)" != "Darwin" ]; then
  fail "macOS only. This script uses launchctl."
fi

MACOS_MAJOR="$(sw_vers -productVersion 2>/dev/null | awk -F. '{print $1}')"
if [ -z "${MACOS_MAJOR}" ] || [ "${MACOS_MAJOR}" -lt 13 ]; then
  fail "Requires macOS 13 (Ventura) or later. Detected: $(sw_vers -productVersion 2>/dev/null || echo unknown)."
fi

if [ ! -x /usr/bin/caffeinate ]; then
  fail "/usr/bin/caffeinate not found. Unusual — try reinstalling Xcode Command Line Tools."
fi

UID_NUM="$(id -u)"
SERVICE_TARGET="gui/${UID_NUM}/${LABEL}"
DOMAIN_TARGET="gui/${UID_NUM}"

agent_loaded() {
  launchctl print "${SERVICE_TARGET}" >/dev/null 2>&1
}

render_plist() {
  if [ ! -f "${TEMPLATE}" ]; then
    fail "Template not found: ${TEMPLATE}"
  fi
  # plist requires absolute paths; launchd does not expand ~ or $HOME.
  sed "s|__HOME__|${HOME}|g" "${TEMPLATE}"
}

# ──────────────────────────────────────────────────────────────────────────
# Actions
# ──────────────────────────────────────────────────────────────────────────
case "${ACTION}" in
  status)
    log "LaunchAgent status:"
    if [ -f "${PLIST_TARGET}" ]; then
      log "  plist file: ${PLIST_TARGET} (exists)"
    else
      log "  plist file: NOT INSTALLED (expected at ${PLIST_TARGET})"
    fi
    if agent_loaded; then
      log "  launchctl:  LOADED as ${SERVICE_TARGET}"
      launchctl print "${SERVICE_TARGET}" 2>/dev/null \
        | grep -E '^[[:space:]]+(state|last exit code|pid|program)[[:space:]]' \
        || true
    else
      log "  launchctl:  NOT LOADED"
    fi
    log "  pmset assertion (if plist-launched caffeinate is running):"
    pmset -g assertions 2>/dev/null | grep -E 'caffeinate.*asserting forever' | head -3 || log "    (no 'asserting forever' caffeinate found)"
    exit 0
    ;;

  uninstall)
    if agent_loaded; then
      log "Unloading ${SERVICE_TARGET}..."
      # bootout by service-target (preferred) then by domain+plist (fallback)
      launchctl bootout "${SERVICE_TARGET}" 2>/dev/null \
        || launchctl bootout "${DOMAIN_TARGET}" "${PLIST_TARGET}" 2>/dev/null \
        || log "  bootout returned non-zero; agent may not have been loaded"
    else
      log "Agent not loaded; skipping bootout."
    fi
    if [ -f "${PLIST_TARGET}" ]; then
      log "Removing ${PLIST_TARGET}"
      rm -f "${PLIST_TARGET}"
    fi
    log "Uninstalled."
    log "  Running caffeinate processes (if any) were not killed."
    log "  To also kill running caffeinate: pkill -u $(id -un) caffeinate"
    exit 0
    ;;

  dry-run|apply)
    log "Rendering plist from ${TEMPLATE}"
    RENDERED="$(render_plist)"
    printf '%s\n' "${RENDERED}" | head -40
    echo "..."

    if [ "${ACTION}" = "dry-run" ]; then
      echo
      dryrun "mkdir -p ${LOG_DIR}"
      dryrun "mkdir -p ${HOME}/Library/LaunchAgents"
      dryrun "write rendered plist to ${PLIST_TARGET}"
      dryrun "chmod 644 ${PLIST_TARGET}"
      dryrun "xattr -c ${PLIST_TARGET}   (strip quarantine — Sonoma gotcha)"
      dryrun "plutil -lint ${PLIST_TARGET}   (validate XML)"
      if agent_loaded; then
        dryrun "launchctl bootout ${SERVICE_TARGET}   (currently loaded; will reload)"
      fi
      dryrun "launchctl bootstrap ${DOMAIN_TARGET} ${PLIST_TARGET}"
      dryrun "launchctl kickstart -k ${SERVICE_TARGET}"
      echo
      log "Dry-run complete. Re-run with --apply to install."
      exit 0
    fi

    # ───── apply ─────
    log "Installing LaunchAgent..."
    mkdir -p "${LOG_DIR}"
    mkdir -p "${HOME}/Library/LaunchAgents"

    # Atomic write (mktemp + mv) to avoid half-written plist mid-install.
    TMP_PLIST="$(mktemp -t mdb-caffeinate.XXXXXX)"
    # Guarantee cleanup of the temp file even if printf/mv fails mid-install
    # under `set -e`. The final `mv` removes TMP_PLIST from disk, so by the
    # time EXIT fires normally there is nothing to remove — making this a
    # no-op on the happy path.
    trap 'rm -f -- "${TMP_PLIST:-}"' EXIT
    printf '%s\n' "${RENDERED}" > "${TMP_PLIST}"
    mv "${TMP_PLIST}" "${PLIST_TARGET}"
    chmod 644 "${PLIST_TARGET}"

    # Strip com.apple.quarantine xattr: bootstrap silently fails on quarantined
    # plists with input/output error on macOS 13+.
    xattr -c "${PLIST_TARGET}" 2>/dev/null || true

    # Validate XML before bootstrap — fail fast with a clearer message than launchd.
    if command -v plutil >/dev/null 2>&1; then
      if ! plutil -lint "${PLIST_TARGET}" >/dev/null; then
        fail "plutil -lint failed on ${PLIST_TARGET}. Inspect and re-run."
      fi
    fi

    # Reload if already bootstrapped (idempotent).
    if agent_loaded; then
      log "Agent already loaded; performing bootout before re-bootstrap..."
      launchctl bootout "${SERVICE_TARGET}" 2>/dev/null || true
      sleep 1
    fi

    log "launchctl bootstrap ${DOMAIN_TARGET} ${PLIST_TARGET}"
    if ! launchctl bootstrap "${DOMAIN_TARGET}" "${PLIST_TARGET}"; then
      fail "bootstrap failed. Inspect: launchctl print ${DOMAIN_TARGET} | grep caffeinate"
    fi

    # Belt + suspenders: kickstart forces start even if RunAtLoad misfired.
    launchctl kickstart -k "${SERVICE_TARGET}" 2>/dev/null || true
    sleep 1

    # Verify
    if agent_loaded; then
      log "[PASS] Agent loaded as ${SERVICE_TARGET}"
      launchctl print "${SERVICE_TARGET}" 2>/dev/null \
        | grep -E '^[[:space:]]+(state|pid|program)[[:space:]]' \
        | head -5 || true
    else
      fail "Agent did not load. Inspect ${LOG_DIR}/com.mobile-dev-bridge.caffeinate.err.log"
    fi

    cat <<'CAVEAT'

[setup-caffeinate] Installed. Important caveats (read these):

  1. Works best on AC power with the lid OPEN on a desk.
     caffeinate's -s flag is silently ignored on battery per Apple spec.

  2. Closed-lid sleep is ENFORCED BY HARDWARE on Apple Silicon (Ventura+)
     regardless of caffeinate or pmset. Options for lid-closed operation:
       a. Keep the lid open (simplest — what this agent assumes).
       b. Clamshell mode: external display + keyboard + AC all connected.

  3. Verify the agent is actually preventing sleep:
       pmset -g assertions | grep 'caffeinate.*asserting forever'

  4. Logs: ~/Library/Logs/com.mobile-dev-bridge.caffeinate.{out,err}.log

  5. Uninstall: ./scripts/setup-caffeinate-launchd.sh --uninstall
CAVEAT
    exit 0
    ;;

  *)
    fail "Unknown action: ${ACTION}"
    ;;
esac
