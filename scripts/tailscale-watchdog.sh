#!/usr/bin/env bash
# tailscale-watchdog.sh — periodic Tailscale reconnect guard (Phase 1.7).
#
# Launched every ~2 min by the com.mobile-dev-bridge.tailscale-watchdog
# LaunchAgent. If the Tailscale backend is Stopped (WantRunning=false — the
# state a GUI toggle-off leaves behind, which persists across reboots), this
# script runs `Tailscale up` so the Mac is always reachable from the iPhone.
#
# Root cause this closes (Block E, 2026-07-06): the macOS Tailscale connect
# toggle is sticky. One accidental "off" and the Mac drops off the tailnet
# forever — caffeinate/sshd/mosh all healthy, yet the iPhone sees "offline".
#
# Design:
#   - Zero dependencies beyond macOS base (grep/sed for JSON, perl for timeout).
#   - Logs ONLY on state transitions and actions — a healthy tick is silent,
#     so the log stays readable and small (plus a size-cap rotation).
#   - Escape hatch: `setup-tailscale-watchdog.sh --pause [hours]` writes a
#     resume-at epoch; the watchdog respects it, then auto-resumes.
#   - NeedsLogin/NeedsMachineAuth are NOT auto-fixed (auth needs a human);
#     they are logged loudly for doctor.sh / verify-tier1.sh to surface.
set -uo pipefail
# -e intentionally omitted: a watchdog must degrade to logging, never die
# silently mid-diagnosis because a probe returned non-zero.

# CRITICAL: force CLI mode on the app-bundle Tailscale binary. Under launchd's
# bare environment (no TERM, no TTY) it tries to start the GUI instead, prints
# "The Tailscale GUI failed to start" — and EXITS 0, which would make every
# probe below silently return empty and neutralize this watchdog. Verified on
# this repo's reference Mac (2026-07-06, v1.96.5 app / 1.98.8 daemon).
# TAILSCALE_BE_CLI is set redundantly here and in the LaunchAgent plist.
export TAILSCALE_BE_CLI=1
export TERM="${TERM:-dumb}"

LABEL="com.mobile-dev-bridge.tailscale-watchdog"
LOG_FILE="${HOME}/Library/Logs/${LABEL}.log"
STATE_DIR="${HOME}/.config/mobile-dev-bridge"
PAUSE_FILE="${STATE_DIR}/watchdog.pause"
LASTSTATE_FILE="${STATE_DIR}/watchdog.laststate"
LOG_MAX_BYTES=524288   # 512 KiB, then rotated to .old (one generation kept)
UP_TIMEOUT_SECS=45     # Tailscale up normally returns in <2s; guard a wedged daemon
PAUSE_DEFAULT_SECS=21600  # 6h fallback when the pause file has no valid epoch

mkdir -p "${STATE_DIR}" "$(dirname "${LOG_FILE}")" 2>/dev/null || true

rotate_log() {
  # stat -f%z is the macOS (BSD) syntax for file size in bytes.
  local size
  size="$(stat -f%z "${LOG_FILE}" 2>/dev/null || echo 0)"
  if [ "${size}" -gt "${LOG_MAX_BYTES}" ]; then
    mv -f "${LOG_FILE}" "${LOG_FILE}.old" 2>/dev/null || true
  fi
}

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "${LOG_FILE}"
}

last_state() { cat "${LASTSTATE_FILE}" 2>/dev/null || echo "unknown"; }
save_state() { printf '%s\n' "$1" > "${LASTSTATE_FILE}" 2>/dev/null || true; }

rotate_log

# ──────────────────────────────────────────────────────────────────────────
# 0. Pause escape hatch (user intentionally disconnected — respect it)
# ──────────────────────────────────────────────────────────────────────────
if [ -f "${PAUSE_FILE}" ]; then
  NOW="$(date +%s)"
  # Strict parse: the first line must be a bare epoch (<=12 digits). Anything
  # else (hand-edited annotations, concatenated digit runs) is treated as
  # corrupt and falls back to mtime+TTL below — never a centuries-long pause.
  RESUME_AT="$(head -1 "${PAUSE_FILE}" 2>/dev/null | grep -oE '^[0-9]{1,12}$' || true)"
  if [ -z "${RESUME_AT}" ]; then
    # Corrupt/empty pause file: honor it for PAUSE_DEFAULT_SECS from its mtime.
    MTIME="$(stat -f%m "${PAUSE_FILE}" 2>/dev/null || echo 0)"
    RESUME_AT="$((MTIME + PAUSE_DEFAULT_SECS))"
  fi
  if [ "${NOW}" -lt "${RESUME_AT}" ]; then
    # Log the skip once per pause period (on transition), not every tick.
    if [ "$(last_state)" != "paused" ]; then
      log "[PAUSE] enforcement paused until $(date -r "${RESUME_AT}" '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || echo "${RESUME_AT}") (${PAUSE_FILE})"
      save_state "paused"
    fi
    exit 0
  fi
  rm -f "${PAUSE_FILE}"
  log "[PAUSE] pause window expired — resuming enforcement"
fi

# ──────────────────────────────────────────────────────────────────────────
# 1. Resolve the Tailscale CLI (app-bundle CLI first: version-matched daemon)
# ──────────────────────────────────────────────────────────────────────────
# Explicit brew paths matter: under launchd PATH is /usr/bin:/bin:/usr/sbin:/sbin,
# so `command -v tailscale` never finds a Homebrew-formula install there.
TS_BIN=""
for cand in "/Applications/Tailscale.app/Contents/MacOS/Tailscale" \
            "/opt/homebrew/bin/tailscale" \
            "/usr/local/bin/tailscale"; do
  if [ -x "${cand}" ]; then
    TS_BIN="${cand}"
    break
  fi
done
if [ -z "${TS_BIN}" ] && command -v tailscale >/dev/null 2>&1; then
  TS_BIN="$(command -v tailscale)"
fi
if [ -z "${TS_BIN}" ]; then
  log "[ERROR] No Tailscale CLI found (app bundle, brew paths, or PATH). Install Tailscale.app."
  save_state "no-cli"
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────
# 2. Read BackendState (grep/sed keeps this jq-free for macOS 13/14)
# ──────────────────────────────────────────────────────────────────────────
STATE="$("${TS_BIN}" status --json 2>/dev/null \
  | grep -m1 -o '"BackendState":[[:space:]]*"[A-Za-z]*"' \
  | sed 's/.*"\([A-Za-z]*\)"$/\1/')"

if [ -z "${STATE}" ]; then
  # CLI present but the IPN daemon (network extension) did not answer.
  # Launching the app (background, hidden) re-registers the extension.
  log "[ERROR] Tailscale daemon unreachable via ${TS_BIN} — attempting 'open -gja Tailscale'"
  open -gja Tailscale 2>/dev/null || log "[ERROR] could not launch Tailscale.app"
  save_state "daemon-unreachable"
  exit 1
fi

case "${STATE}" in
  Running)
    if [ "$(last_state)" != "Running" ]; then
      log "[OK] BackendState=Running (recovered from '$(last_state)')"
    fi
    save_state "Running"
    exit 0
    ;;

  Stopped)
    log "[ACTION] BackendState=Stopped (WantRunning=false) — running '${TS_BIN} up'"
    # perl-alarm is the dependency-free macOS timeout(1) equivalent.
    # Plain `up` (no flags) preserves existing prefs and only flips
    # WantRunning=true — verified on this repo's reference Mac (v1.96.5,
    # RouteAll/CorpDNS survived; see CHANGELOG [0.5.0] research notes).
    if perl -e 'alarm shift; exec @ARGV' "${UP_TIMEOUT_SECS}" "${TS_BIN}" up >> "${LOG_FILE}" 2>&1; then
      NEW_STATE="$("${TS_BIN}" status --json 2>/dev/null \
        | grep -m1 -o '"BackendState":[[:space:]]*"[A-Za-z]*"' \
        | sed 's/.*"\([A-Za-z]*\)"$/\1/')"
      log "[RESULT] up succeeded — BackendState=${NEW_STATE:-unknown}"
      save_state "${NEW_STATE:-unknown}"
    else
      log "[ERROR] 'up' failed or timed out after ${UP_TIMEOUT_SECS}s — will retry next interval"
      save_state "up-failed"
      exit 1
    fi
    ;;

  Starting|NoState)
    # Transient boot/reconnect states — do not interfere; next tick re-checks.
    if [ "$(last_state)" != "${STATE}" ]; then
      log "[WAIT] BackendState=${STATE} (transient) — no action"
    fi
    save_state "${STATE}"
    ;;

  NeedsLogin|NeedsMachineAuth)
    # Re-auth requires a human (browser SSO / admin approval). Log loudly;
    # verify-tier1.sh item 1 and doctor.sh L1 will surface this to the user.
    if [ "$(last_state)" != "${STATE}" ]; then
      log "[NEEDS-HUMAN] BackendState=${STATE} — cannot fix unattended. Run 'tailscale up' in a terminal or open Tailscale.app and re-authenticate."
    fi
    save_state "${STATE}"
    exit 1
    ;;

  *)
    log "[WARN] Unrecognized BackendState='${STATE}' — no action taken"
    save_state "${STATE}"
    ;;
esac
exit 0
