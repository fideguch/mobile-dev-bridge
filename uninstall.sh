#!/usr/bin/env bash
# uninstall.sh — Remove the Claude Code skill symlink only. Keeps the repo untouched.
set -euo pipefail

TARGET_LINK="${HOME}/.claude/skills/mobile-dev-bridge"

log() { printf '[uninstall] %s\n' "$*"; }

if [ -L "${TARGET_LINK}" ]; then
  log "Removing symlink: ${TARGET_LINK}"
  rm "${TARGET_LINK}"
  log "Done. The ~/mobile-dev-bridge/ repo is untouched."
elif [ -e "${TARGET_LINK}" ]; then
  log "WARN: ${TARGET_LINK} exists but is not a symlink. Not removing. Inspect manually."
  exit 1
else
  log "Symlink not found. Nothing to do."
fi
