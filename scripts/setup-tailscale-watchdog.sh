#!/usr/bin/env bash
# setup-tailscale-watchdog.sh — Install/uninstall the Tailscale watchdog
# LaunchAgent (Phase 1.7).
#
# The watchdog (scripts/tailscale-watchdog.sh) runs every 2 minutes and flips
# Tailscale back to connected when the backend is Stopped (WantRunning=false).
# Without it, one accidental toggle-off makes the Mac invisible to the iPhone
# forever — the toggle state persists across reboots (Block E, 2026-07-06).
#
# HARD-GATE #1: default dry-run. --apply required to load the agent.
# Idempotent: safe to re-run; reloads existing agent cleanly.
# Requires macOS 13 (Ventura) or later — uses `launchctl bootstrap`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/../templates/com.mobile-dev-bridge.tailscale-watchdog.plist.template"
WATCHDOG_SCRIPT="${SCRIPT_DIR}/tailscale-watchdog.sh"
LABEL="com.mobile-dev-bridge.tailscale-watchdog"
PLIST_TARGET="${HOME}/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="${HOME}/Library/Logs"
WATCHDOG_LOG="${LOG_DIR}/${LABEL}.log"
STATE_DIR="${HOME}/.config/mobile-dev-bridge"
PAUSE_FILE="${STATE_DIR}/watchdog.pause"
PAUSE_DEFAULT_HOURS=6

ACTION="dry-run"
PAUSE_HOURS="${PAUSE_DEFAULT_HOURS}"
EXPECT_PAUSE_HOURS=0
for arg in "$@"; do
  if [ "${EXPECT_PAUSE_HOURS}" -eq 1 ]; then
    EXPECT_PAUSE_HOURS=0
    case "${arg}" in
      ''|*[!0-9]*)
        printf '[setup-ts-watchdog][ERROR] --pause expects whole hours, got: %s\n' "${arg}" >&2
        exit 2 ;;
      *) PAUSE_HOURS="${arg}"; continue ;;
    esac
  fi
  case "${arg}" in
    --apply)     ACTION="apply" ;;
    --uninstall) ACTION="uninstall" ;;
    --status)    ACTION="status" ;;
    --run-once)  ACTION="run-once" ;;
    --pause)     ACTION="pause"; EXPECT_PAUSE_HOURS=1 ;;
    --resume)    ACTION="resume" ;;
    --help|-h)
      cat <<USAGE
Usage: setup-tailscale-watchdog.sh [--apply|--uninstall|--status|--run-once|--pause [hours]|--resume]

  (no flag)     Dry-run. Prints planned actions. No changes to system.
  --apply       Install and load the LaunchAgent (idempotent).
  --uninstall   Unload and remove the LaunchAgent.
  --status      Show LaunchAgent, pause, and Tailscale backend state.
  --run-once    Execute the watchdog check right now and show the log tail.
  --pause [N]   Pause enforcement for N hours (default ${PAUSE_DEFAULT_HOURS}) —
                use when you INTENTIONALLY want Tailscale off. Auto-resumes.
  --resume      Clear the pause immediately.

Installs ~/Library/LaunchAgents/${LABEL}.plist that runs
  scripts/tailscale-watchdog.sh
every 2 minutes: if Tailscale's BackendState is Stopped, it runs
'Tailscale up' so the Mac never silently drops off the tailnet.
Requires macOS 13+ (uses launchctl bootstrap/bootout subcommands).

See references/setup-tier1.md §12 for design rationale and caveats.
USAGE
      exit 0 ;;
    *)
      printf '[setup-ts-watchdog][ERROR] Unknown arg: %s\n' "${arg}" >&2
      exit 2 ;;
  esac
done

log()    { printf '[setup-ts-watchdog] %s\n' "$*"; }
dryrun() { printf '[setup-ts-watchdog][DRY-RUN] Would run: %s\n' "$*"; }
fail()   { printf '[setup-ts-watchdog][ERROR] %s\n' "$*" >&2; exit 1; }

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

if [ ! -f "${WATCHDOG_SCRIPT}" ]; then
  fail "Watchdog script not found: ${WATCHDOG_SCRIPT}"
fi

UID_NUM="$(id -u)"
SERVICE_TARGET="gui/${UID_NUM}/${LABEL}"
DOMAIN_TARGET="gui/${UID_NUM}"

agent_loaded() {
  launchctl print "${SERVICE_TARGET}" >/dev/null 2>&1
}

# XML-escape a value before embedding it in the plist. Without this, a path
# containing '&' or '<' renders invalid (or, with sed, silently corrupted) XML.
xml_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  printf '%s' "${s}"
}

render_plist() {
  if [ ! -f "${TEMPLATE}" ]; then
    fail "Template not found: ${TEMPLATE}"
  fi
  # plist requires absolute paths; launchd does not expand ~ or $HOME.
  # Bash parameter expansion is used instead of sed: sed's replacement text
  # treats '&' and '\' as metacharacters, so a repo path like ~/R&D/... would
  # silently corrupt ProgramArguments while still passing plutil -lint.
  local content
  content="$(cat "${TEMPLATE}")"
  content="${content//__HOME__/$(xml_escape "${HOME}")}"
  content="${content//__WATCHDOG_SCRIPT__/$(xml_escape "${WATCHDOG_SCRIPT}")}"
  printf '%s\n' "${content}"
}

backend_state() {
  # Same CLI-mode forcing and resolution chain as the watchdog itself
  # (see tailscale-watchdog.sh — brew paths are absent from launchd's PATH).
  export TAILSCALE_BE_CLI=1
  export TERM="${TERM:-dumb}"
  local ts_bin="" cand
  for cand in "/Applications/Tailscale.app/Contents/MacOS/Tailscale" \
              "/opt/homebrew/bin/tailscale" \
              "/usr/local/bin/tailscale"; do
    if [ -x "${cand}" ]; then
      ts_bin="${cand}"
      break
    fi
  done
  if [ -z "${ts_bin}" ] && command -v tailscale >/dev/null 2>&1; then
    ts_bin="$(command -v tailscale)"
  fi
  if [ -z "${ts_bin}" ]; then
    echo "no-cli"
    return
  fi
  "${ts_bin}" status --json 2>/dev/null \
    | grep -m1 -o '"BackendState":[[:space:]]*"[A-Za-z]*"' \
    | sed 's/.*"\([A-Za-z]*\)"$/\1/' \
    || echo "unknown"
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
    if [ -f "${PAUSE_FILE}" ]; then
      RESUME_AT="$(head -1 "${PAUSE_FILE}" 2>/dev/null | grep -oE '^[0-9]{1,12}$' || true)"
      if [ -n "${RESUME_AT}" ]; then
        log "  pause:      ACTIVE until $(date -r "${RESUME_AT}" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo "epoch ${RESUME_AT}")"
      else
        log "  pause:      ACTIVE (no epoch in file — honored ~6h from file mtime)"
      fi
    else
      log "  pause:      none (enforcement active)"
    fi
    log "  Tailscale BackendState: $(backend_state)"
    log "  watchdog log tail (${WATCHDOG_LOG}):"
    tail -5 "${WATCHDOG_LOG}" 2>/dev/null | sed 's/^/    /' || log "    (no log yet)"
    exit 0
    ;;

  run-once)
    log "Running watchdog check once..."
    bash "${WATCHDOG_SCRIPT}" || true
    log "BackendState now: $(backend_state)"
    log "log tail:"
    tail -5 "${WATCHDOG_LOG}" 2>/dev/null | sed 's/^/    /' || log "    (no log yet — a healthy tick writes nothing)"
    exit 0
    ;;

  pause)
    mkdir -p "${STATE_DIR}"
    # 10# forces base-10: "--pause 010" would otherwise be octal (8h), and
    # "--pause 08" would abort with bash's cryptic "value too great for base".
    RESUME_EPOCH="$(( $(date +%s) + 10#${PAUSE_HOURS} * 3600 ))"
    printf '%s\n' "${RESUME_EPOCH}" > "${PAUSE_FILE}"
    log "Watchdog enforcement PAUSED for ${PAUSE_HOURS}h (until $(date -r "${RESUME_EPOCH}" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo "epoch ${RESUME_EPOCH}"))."
    log "Tailscale can now be toggled off without the watchdog reverting it."
    log "Resume early with: $0 --resume"
    exit 0
    ;;

  resume)
    if [ -f "${PAUSE_FILE}" ]; then
      rm -f "${PAUSE_FILE}"
      log "Pause cleared — enforcement active again (next check within 2 min)."
    else
      log "No pause was active. Nothing to do."
    fi
    exit 0
    ;;

  uninstall)
    if agent_loaded; then
      log "Unloading ${SERVICE_TARGET}..."
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
    log "Uninstalled. Logs and ${STATE_DIR} state files were kept."
    exit 0
    ;;

  dry-run|apply)
    log "Rendering plist from ${TEMPLATE}"
    RENDERED="$(render_plist)"
    printf '%s\n' "${RENDERED}" | head -50
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
    TMP_PLIST="$(mktemp -t mdb-ts-watchdog.XXXXXX)"
    trap 'rm -f -- "${TMP_PLIST:-}"' EXIT
    printf '%s\n' "${RENDERED}" > "${TMP_PLIST}"
    mv "${TMP_PLIST}" "${PLIST_TARGET}"
    chmod 644 "${PLIST_TARGET}"

    # Strip com.apple.quarantine xattr: bootstrap silently fails on quarantined
    # plists with input/output error on macOS 13+.
    xattr -c "${PLIST_TARGET}" 2>/dev/null || true

    if command -v plutil >/dev/null 2>&1; then
      if ! plutil -lint "${PLIST_TARGET}" >/dev/null; then
        fail "plutil -lint failed on ${PLIST_TARGET}. Inspect and re-run."
      fi
      # End-to-end render check: extract the script path back out of the
      # installed plist (plutil un-escapes XML) and require an exact match.
      # Catches any placeholder-substitution corruption before bootstrap.
      RENDERED_SCRIPT="$(plutil -extract ProgramArguments.1 raw "${PLIST_TARGET}" 2>/dev/null || true)"
      if [ "${RENDERED_SCRIPT}" != "${WATCHDOG_SCRIPT}" ]; then
        fail "Rendered plist ProgramArguments mismatch: '${RENDERED_SCRIPT}' != '${WATCHDOG_SCRIPT}'. Inspect ${PLIST_TARGET}."
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
      fail "bootstrap failed. Inspect: launchctl print ${DOMAIN_TARGET} | grep tailscale-watchdog"
    fi

    # Belt + suspenders: kickstart forces the first run even if RunAtLoad misfired.
    launchctl kickstart -k "${SERVICE_TARGET}" 2>/dev/null || true
    sleep 2

    if agent_loaded; then
      log "[PASS] Agent loaded as ${SERVICE_TARGET}"
      log "BackendState now: $(backend_state)"
    else
      fail "Agent did not load. Inspect ${LOG_DIR}/${LABEL}.err.log"
    fi

    cat <<'CAVEAT'

[setup-ts-watchdog] Installed. What this does and does not cover:

  1. COVERS: accidental Tailscale toggle-off / `tailscale down` — reverted
     within ~2 minutes. The macOS toggle is sticky across reboots; this
     agent removes that whole failure class (Block E).

  2. COVERS: daemon answered but stopped; app extension unreachable
     (relaunches Tailscale.app in the background).

  3. DOES NOT COVER: logged-out state (NeedsLogin) — re-auth needs a human
     in a browser. The watchdog logs [NEEDS-HUMAN] loudly instead.

  4. DOES NOT COVER: Mac powered off / lid closed on battery / FileVault
     pre-boot. See references/setup-tier1.md §8-3 and §12.

  5. Intentionally going off-tailnet? Pause enforcement first:
       ./scripts/setup-tailscale-watchdog.sh --pause 2   # hours

  6. Logs: ~/Library/Logs/com.mobile-dev-bridge.tailscale-watchdog.log
     (healthy ticks are silent; only transitions/actions are logged)

  7. Uninstall: ./scripts/setup-tailscale-watchdog.sh --uninstall
CAVEAT
    exit 0
    ;;

  *)
    fail "Unknown action: ${ACTION}"
    ;;
esac
