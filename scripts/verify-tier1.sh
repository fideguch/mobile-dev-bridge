#!/usr/bin/env bash
# verify-tier1.sh — 6-item smoke test for Tier 1 stack.
# Returns 0 if all pass, non-zero if any fail. Safe to re-run.
set -uo pipefail
# -e intentionally omitted: we collect failures across multiple layers and
# print a summary at the end. Using -e would short-circuit on the first FAIL
# and hide the rest of the diagnostic output.

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { printf '  [PASS] %s\n' "$*"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf '  [FAIL] %s\n' "$*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
# NOTE: warn()/WARN_COUNT intentionally removed when item 6 was promoted from
# WARN to FAIL in v0.3.0. All current checks are strict PASS/FAIL. Re-introduce
# warn() as needed for future non-blocking checks. WARN_COUNT is retained in
# the summary output for backward compatibility with consumers that parsed it.

echo "[verify-tier1] 6-item smoke test"
echo

# ──────────────────────────────────────────────────────────────────────────
# 1. Tailscale up
# ──────────────────────────────────────────────────────────────────────────
echo "1) Tailscale status"
if command -v tailscale >/dev/null 2>&1; then
  if tailscale status >/dev/null 2>&1; then
    pass "tailscale status reachable (daemon up + authenticated)"
  else
    fail "tailscale installed but 'tailscale status' failed. Try: sudo tailscale up"
  fi
else
  fail "tailscale not installed. Run: ./scripts/install-tier1.sh --apply"
fi

# ──────────────────────────────────────────────────────────────────────────
# 2. mosh-server reachable via loopback (just verifies binary exists + launches)
# ──────────────────────────────────────────────────────────────────────────
echo "2) mosh-server loopback"
if command -v mosh-server >/dev/null 2>&1; then
  # mosh-server prints "MOSH CONNECT <port> <key>" on stdout and version banner
  # on stderr. With 2>&1 merge, line ordering is flush-timing dependent, so
  # reading only the first line (head -1) is flaky. Read up to 8 lines within
  # a bounded window, kill the server, then scan for the MOSH CONNECT token.
  MOSH_OUT=$(mosh-server new -v 2>&1 | head -8 || true)
  pkill -u "$(id -un)" -f 'mosh-server new' 2>/dev/null || true
  if printf '%s\n' "$MOSH_OUT" | grep -q 'MOSH CONNECT'; then
    pass "mosh-server launches and prints MOSH CONNECT handshake"
  else
    FIRST_LINE=$(printf '%s\n' "$MOSH_OUT" | head -1)
    fail "mosh-server did not produce expected MOSH CONNECT output (first line was: '${FIRST_LINE}')"
  fi
else
  fail "mosh-server not found. Run: ./scripts/install-tier1.sh --apply"
fi

# ──────────────────────────────────────────────────────────────────────────
# 3. tmux new-session test
# ──────────────────────────────────────────────────────────────────────────
echo "3) tmux new-session"
if command -v tmux >/dev/null 2>&1; then
  SESSION_NAME="mdb-verify-$$"
  if tmux new-session -d -s "${SESSION_NAME}" 'sleep 0.5' 2>/dev/null; then
    pass "tmux creates detached session '${SESSION_NAME}'"
    tmux kill-session -t "${SESSION_NAME}" 2>/dev/null || true
  else
    fail "tmux could not create a new session"
  fi
else
  fail "tmux not installed. Run: ./scripts/install-tier1.sh --apply"
fi

# ──────────────────────────────────────────────────────────────────────────
# 4. Claude CLI
# ──────────────────────────────────────────────────────────────────────────
echo "4) Claude Code CLI"
if command -v claude >/dev/null 2>&1; then
  CLAUDE_VER="$(claude --version 2>/dev/null | head -1 || echo '')"
  if [ -n "${CLAUDE_VER}" ]; then
    pass "claude --version: ${CLAUDE_VER}"
  else
    fail "claude found but --version produced no output"
  fi
else
  fail "claude not in PATH. See https://docs.anthropic.com/en/docs/claude-code"
fi

# ──────────────────────────────────────────────────────────────────────────
# 5. SSH key (primary or mobile-dedicated)
# ──────────────────────────────────────────────────────────────────────────
echo "5) SSH key present"
if [ -f "${HOME}/.ssh/id_ed25519" ] || [ -f "${HOME}/.ssh/id_ed25519_mobile" ]; then
  if [ -f "${HOME}/.ssh/id_ed25519_mobile" ]; then
    pass "${HOME}/.ssh/id_ed25519_mobile exists"
  else
    pass "${HOME}/.ssh/id_ed25519 exists (consider a dedicated id_ed25519_mobile for iPhone)"
  fi
else
  fail "No ED25519 SSH key found. Run: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_mobile"
fi

# ──────────────────────────────────────────────────────────────────────────
# 6. caffeinate LaunchAgent (Phase 1.5: keeps Mac awake 24/7 for remote SSH)
# ──────────────────────────────────────────────────────────────────────────
echo "6) caffeinate LaunchAgent (Phase 1.5)"
LAUNCHAGENT_PLIST="${HOME}/Library/LaunchAgents/com.mobile-dev-bridge.caffeinate.plist"
SERVICE_TARGET="gui/$(id -u)/com.mobile-dev-bridge.caffeinate"
if [ -f "${LAUNCHAGENT_PLIST}" ] && launchctl print "${SERVICE_TARGET}" >/dev/null 2>&1; then
  pass "caffeinate LaunchAgent loaded (${SERVICE_TARGET})"
elif command -v caffeinate >/dev/null 2>&1; then
  fail "caffeinate LaunchAgent not installed. Run: ./scripts/setup-caffeinate-launchd.sh --apply"
else
  fail "caffeinate binary missing. Reinstall Xcode Command Line Tools."
fi

# ──────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────
echo
echo "[verify-tier1] Summary: ${PASS_COUNT} pass / ${FAIL_COUNT} fail / ${WARN_COUNT} warn"
if [ "${FAIL_COUNT}" -gt 0 ]; then
  echo "[verify-tier1] Overall: FAIL. Run ./scripts/doctor.sh for remediation hints."
  exit 1
fi
echo "[verify-tier1] Overall: PASS"
exit 0
