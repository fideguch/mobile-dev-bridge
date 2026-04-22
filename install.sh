#!/usr/bin/env bash
# install.sh — Install mobile-dev-bridge as a Claude Code skill (symlink only)
# Idempotent: safe to re-run. Does not install brew packages (that's scripts/install-tier1.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
TARGET_NAME="mobile-dev-bridge"
TARGET_LINK="${CLAUDE_SKILLS_DIR}/${TARGET_NAME}"

log()  { printf '[install] %s\n' "$*"; }
fail() { printf '[install][ERROR] %s\n' "$*" >&2; exit 1; }

# 1. Verify Claude Code is installed (informational check, not a hard blocker)
if ! command -v claude >/dev/null 2>&1; then
  log "WARN: 'claude' CLI not found in PATH. The symlink will still be created,"
  log "      but Claude Code won't be able to use this skill until you install it."
  log "      See: https://docs.anthropic.com/en/docs/claude-code"
fi

# 2. Ensure ~/.claude/skills exists
if [ ! -d "${CLAUDE_SKILLS_DIR}" ]; then
  log "Creating ${CLAUDE_SKILLS_DIR}"
  mkdir -p "${CLAUDE_SKILLS_DIR}"
fi

# 3. Create / refresh the symlink idempotently
if [ -L "${TARGET_LINK}" ]; then
  EXISTING_TARGET="$(readlink "${TARGET_LINK}")"
  if [ "${EXISTING_TARGET}" = "${SCRIPT_DIR}" ]; then
    log "Symlink already correct: ${TARGET_LINK} -> ${SCRIPT_DIR}"
  else
    log "Updating symlink (was: ${EXISTING_TARGET})"
    ln -sfn "${SCRIPT_DIR}" "${TARGET_LINK}"
  fi
elif [ -e "${TARGET_LINK}" ]; then
  fail "${TARGET_LINK} exists and is NOT a symlink. Manually remove/back up first."
else
  log "Creating symlink: ${TARGET_LINK} -> ${SCRIPT_DIR}"
  ln -s "${SCRIPT_DIR}" "${TARGET_LINK}"
fi

# 4. Confirm
if [ "$(readlink "${TARGET_LINK}")" = "${SCRIPT_DIR}" ]; then
  log "OK. Claude Code should now find the 'mobile-dev-bridge' skill."
  log "Next: ./scripts/install-tier1.sh   (dry-run by default)"
else
  fail "Symlink verification failed."
fi
