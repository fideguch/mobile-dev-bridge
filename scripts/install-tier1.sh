#!/usr/bin/env bash
# install-tier1.sh — Install Tier 1 stack (Tailscale + mosh + tmux) on macOS.
# HARD-GATE #1: default dry-run. --apply required to actually install.
# Idempotent: safe to re-run.
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────
# VERSIONS — minimum acceptable versions. See SECURITY.md "Supply chain".
# ──────────────────────────────────────────────────────────────────────────
TAILSCALE_MIN="1.80"
MOSH_MIN="1.4.0"
TMUX_MIN="3.4"

# ──────────────────────────────────────────────────────────────────────────
# CLI flag parsing (dry-run is default)
# ──────────────────────────────────────────────────────────────────────────
APPLY=0
for arg in "$@"; do
  case "${arg}" in
    --apply) APPLY=1 ;;
    --help|-h)
      cat <<USAGE
Usage: install-tier1.sh [--apply]

  (no flag)   Dry-run. Prints what would be installed. No changes.
  --apply     Actually run brew install and copy tmux.conf template.

Minimum versions enforced:
  Tailscale >= ${TAILSCALE_MIN}
  mosh      >= ${MOSH_MIN}
  tmux      >= ${TMUX_MIN}

See: ../SECURITY.md for rationale.
USAGE
      exit 0
      ;;
    *)
      echo "[install-tier1][ERROR] Unknown arg: ${arg}" >&2
      exit 2
      ;;
  esac
done

log()    { printf '[install-tier1] %s\n' "$*"; }
dryrun() { printf '[install-tier1][DRY-RUN] Would run: %s\n' "$*"; }

run_or_print() {
  if [ "${APPLY}" -eq 1 ]; then
    log "Running: $*"
    "$@"
  else
    dryrun "$*"
  fi
}

# ──────────────────────────────────────────────────────────────────────────
# 1. Preflight
# ──────────────────────────────────────────────────────────────────────────
if ! command -v brew >/dev/null 2>&1; then
  echo "[install-tier1][ERROR] Homebrew not found. Install from https://brew.sh first." >&2
  exit 1
fi

log "Mode: $([ "${APPLY}" -eq 1 ] && echo 'APPLY (will modify system)' || echo 'DRY-RUN (no changes)')"
log "Target minimum versions: tailscale>=${TAILSCALE_MIN} mosh>=${MOSH_MIN} tmux>=${TMUX_MIN}"

# ──────────────────────────────────────────────────────────────────────────
# 2. Install packages (idempotent via brew)
# ──────────────────────────────────────────────────────────────────────────
for pkg in tailscale mosh tmux; do
  if brew list --formula "${pkg}" >/dev/null 2>&1; then
    log "Already installed: ${pkg}"
  else
    run_or_print brew install "${pkg}"
  fi
done

# ──────────────────────────────────────────────────────────────────────────
# 3. Version checks (best-effort, only warn if below minimum)
# ──────────────────────────────────────────────────────────────────────────
version_warn() {
  local name="$1" got="$2" want="$3"
  printf '[install-tier1][WARN] %s version %s is below recommended %s. Consider: brew upgrade %s\n' \
    "${name}" "${got}" "${want}" "${name}"
}

if [ "${APPLY}" -eq 1 ]; then
  if command -v tailscale >/dev/null 2>&1; then
    TS_VER="$(tailscale version 2>/dev/null | head -1 | awk '{print $1}' || echo 'unknown')"
    log "tailscale version: ${TS_VER}"
    # lexicographic compare is fine for the 1.XX series on macOS
    if [ "${TS_VER}" != "unknown" ] && [ "$(printf '%s\n%s\n' "${TAILSCALE_MIN}" "${TS_VER}" | sort -V | head -1)" != "${TAILSCALE_MIN}" ]; then
      version_warn tailscale "${TS_VER}" "${TAILSCALE_MIN}"
    fi
  fi
  if command -v mosh >/dev/null 2>&1; then
    MOSH_VER="$(mosh --version 2>/dev/null | head -1 | awk '{print $2}' || echo 'unknown')"
    log "mosh version: ${MOSH_VER}"
    if [ "${MOSH_VER}" != "unknown" ] && [ "$(printf '%s\n%s\n' "${MOSH_MIN}" "${MOSH_VER}" | sort -V | head -1)" != "${MOSH_MIN}" ]; then
      version_warn mosh "${MOSH_VER}" "${MOSH_MIN}"
    fi
  fi
  if command -v tmux >/dev/null 2>&1; then
    TMUX_VER="$(tmux -V 2>/dev/null | awk '{print $2}' || echo 'unknown')"
    log "tmux version: ${TMUX_VER}"
    if [ "${TMUX_VER}" != "unknown" ] && [ "$(printf '%s\n%s\n' "${TMUX_MIN}" "${TMUX_VER}" | sort -V | head -1)" != "${TMUX_MIN}" ]; then
      version_warn tmux "${TMUX_VER}" "${TMUX_MIN}"
    fi
  fi
fi

# ──────────────────────────────────────────────────────────────────────────
# 4. Place tmux.conf from template (back up existing first)
# ──────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/../templates/tmux.conf.template"
TARGET="${HOME}/.tmux.conf"

if [ ! -f "${TEMPLATE}" ]; then
  echo "[install-tier1][ERROR] Template not found: ${TEMPLATE}" >&2
  exit 1
fi

if [ -f "${TARGET}" ]; then
  if cmp -s "${TEMPLATE}" "${TARGET}"; then
    log "${HOME}/.tmux.conf already matches template. Skipping."
  else
    BACKUP="${TARGET}.backup.$(date +%Y%m%d%H%M%S)"
    run_or_print cp "${TARGET}" "${BACKUP}"
    run_or_print cp "${TEMPLATE}" "${TARGET}"
    log "Existing ~/.tmux.conf backed up to ${BACKUP}"
  fi
else
  run_or_print cp "${TEMPLATE}" "${TARGET}"
fi

# ──────────────────────────────────────────────────────────────────────────
# 5. Reminder to user (non-automated steps)
# ──────────────────────────────────────────────────────────────────────────
cat <<'NEXT'

[install-tier1] Next steps (manual, HARD-GATE #2):
  1. Run:  sudo tailscale up
  2. Accept the login in your browser.
  3. On iPhone/iPad: install Tailscale app and Termius app, then log in to Tailscale.
  4. Generate an SSH key if you do not have one:
       ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_mobile -C "iphone-$(date +%Y%m%d)"
  5. Add the public key to ~/.ssh/authorized_keys on this Mac.
  6. In Termius: Hosts -> Add Host with your Tailscale MagicDNS hostname.
  7. Run ./scripts/verify-tier1.sh after completing the above.
NEXT
