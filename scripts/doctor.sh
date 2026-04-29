#!/usr/bin/env bash
# doctor.sh — Layered diagnostic wrapping verify-tier1 with actionable remediation.
# Non-destructive. Safe to re-run any time.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="${SCRIPT_DIR}/verify-tier1.sh"

if [ ! -x "${VERIFY_SCRIPT}" ]; then
  echo "[doctor][ERROR] verify-tier1.sh not found or not executable at ${VERIFY_SCRIPT}" >&2
  exit 2
fi

echo "══════════════════════════════════════════════════════════════════════"
echo " mobile-dev-bridge doctor — 9-layer diagnostic"
echo "══════════════════════════════════════════════════════════════════════"
echo

# Run verify-tier1 (which covers L1-L5 + caffeinate warn). Capture output for recap.
TMP_OUT="$(mktemp -t mdb-doctor.XXXXXX)"
trap 'rm -f "${TMP_OUT}"' EXIT

set +e
"${VERIFY_SCRIPT}" | tee "${TMP_OUT}"
VERIFY_EXIT=$?
set -e

echo
echo "══════════════════════════════════════════════════════════════════════"
echo " Remediation hints (per verify-tier1.sh item)"
echo "══════════════════════════════════════════════════════════════════════"

# NOTE: the grep patterns below rely on verify-tier1.sh output ordering
# ("1) Tailscale", "2) mosh-server" etc.). If that script's section
# headers change, update the patterns here in lock-step. A tests/
# regression guard is planned for Phase 2.

# L1: Tailscale 🔐 トンネル
if grep -q '1) Tailscale' "${TMP_OUT}" && grep -A1 '1) Tailscale' "${TMP_OUT}" | grep -q FAIL; then
  cat <<'HINT_L1'

L1 🔐 トンネル — Tailscale FAIL:
  - Reinstall:        brew reinstall tailscale
  - Auth daemon:      sudo tailscale up
  - Manual browser:   open https://login.tailscale.com/admin/machines
  - Check daemon:     launchctl print system | grep tailscale
  See references/troubleshooting.md §L1 for deep dive.
HINT_L1
fi

# L2: SSH 🗝️ 鍵付きドア (key absence is covered by L5 in verify-tier1, but SSH agent/config is separate)
if grep -q '5) SSH key' "${TMP_OUT}" && grep -A1 '5) SSH key' "${TMP_OUT}" | grep -q FAIL; then
  cat <<'HINT_L2'

L2 🗝️ 鍵付きドア — SSH FAIL (no key):
  - Generate:         ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_mobile -C "iphone-$(date +%Y%m%d)"
  - Authorize:        cat ~/.ssh/id_ed25519_mobile.pub >> ~/.ssh/authorized_keys
  - Perms:            chmod 600 ~/.ssh/authorized_keys; chmod 700 ~/.ssh
  See references/troubleshooting.md §L2 and references/security.md.
HINT_L2
fi

# L3: mosh 🎣 ケーブル
if grep -q '2) mosh-server' "${TMP_OUT}" && grep -A1 '2) mosh-server' "${TMP_OUT}" | grep -q FAIL; then
  cat <<'HINT_L3'

L3 🎣 ケーブル — mosh FAIL:
  - Reinstall:        brew reinstall mosh
  - UDP port check:   sudo lsof -i UDP | grep mosh
  - Locale (common):  export LC_ALL=en_US.UTF-8 (add to ~/.zshrc)
  - Firewall:         System Settings > Network > Firewall — allow mosh-server
  See references/troubleshooting.md §L3.
HINT_L3
fi

# L4: tmux 📦 ボックス
if grep -q '3) tmux' "${TMP_OUT}" && grep -A1 '3) tmux' "${TMP_OUT}" | grep -q FAIL; then
  cat <<'HINT_L4'

L4 📦 ボックス — tmux FAIL:
  - Reinstall:        brew reinstall tmux
  - Kill stale:       tmux kill-server
  - Config check:     tmux -f ~/.tmux.conf new -d -s test && tmux kill-session -t test
  See references/troubleshooting.md §L4.
HINT_L4
fi

# L5: Claude CLI 🤖 AI
if grep -q '4) Claude Code CLI' "${TMP_OUT}" && grep -A1 '4) Claude Code CLI' "${TMP_OUT}" | grep -q FAIL; then
  cat <<'HINT_L5'

L5 🤖 AI — Claude Code CLI FAIL:
  - Install:          See https://docs.anthropic.com/en/docs/claude-code
  - PATH:             which claude || echo "not in PATH"
  - Reload shell:     exec $SHELL -l
  See references/troubleshooting.md §L5.
HINT_L5
fi

# L6: caffeinate LaunchAgent 💤 Sleep guard (Phase 1.5 gate)
if grep -q '6) caffeinate LaunchAgent' "${TMP_OUT}" && grep -A1 '6) caffeinate LaunchAgent' "${TMP_OUT}" | grep -q FAIL; then
  cat <<HINT_CAFFEINATE

L6 💤 Sleep guard — caffeinate LaunchAgent FAIL:
  - Install:        ./scripts/setup-caffeinate-launchd.sh --apply
  - Dry-run first:  ./scripts/setup-caffeinate-launchd.sh
  - Status check:   ./scripts/setup-caffeinate-launchd.sh --status
  - launchctl:      launchctl print gui/$(id -u)/com.mobile-dev-bridge.caffeinate
  - pmset proof:    pmset -g assertions | grep 'caffeinate.*asserting forever'
  - Uninstall:      ./scripts/setup-caffeinate-launchd.sh --uninstall
  Without this, the Mac sleeps and iPhone SSH/mosh connections fail silently.
  See references/setup-tier1.md §8 (lid-closed / Apple Silicon caveats) and
  references/troubleshooting.md §L6.
HINT_CAFFEINATE
fi

# L7: Remote Login (sshd) — verify-tier1 item 7
if grep -q '7) Remote Login' "${TMP_OUT}" && grep -A1 '7) Remote Login' "${TMP_OUT}" | grep -q FAIL; then
  cat <<'HINT_L7_SSHD'

L7 — Remote Login (sshd TCP/22) FAIL:
  - GUI fix:          System Settings → General → Sharing → Remote Login = ON
  - CLI fix:          sudo systemsetup -setremotelogin on
                      (macOS 13+ may need Terminal-with-FDA; GUI is more reliable)
  - macOS 13+ note:   sshd is launchd-managed (on-demand). 'pgrep sshd' may show
                      nothing while idle; the port only opens at connection time.
                      A TCP probe (nc -z 127.0.0.1 22) is the reliable check.
  See references/troubleshooting.md §L2.
HINT_L7_SSHD
fi

# L8: Tailscale ↔ sshd path — verify-tier1 item 8
if grep -q '8) Tailscale-IP' "${TMP_OUT}" && grep -A1 '8) Tailscale-IP' "${TMP_OUT}" | grep -q FAIL; then
  cat <<'HINT_L8'

L8 — Tailscale-IP TCP/22 path FAIL:
  - First:            re-check L7. If item 7 FAILs, item 8 cannot pass.
  - macOS Firewall:   /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
                      If 'enabled', allow sshd or set 'Block all incoming' = OFF.
  - Tailscale ACL:    https://login.tailscale.com/admin/acls — verify the device
                      tag/user is permitted to reach this Mac on TCP/22.
  - Diagnose path:    tailscale ip -4         # confirm IP we are testing
                      tailscale ping <peer>   # verify P2P path is up
  See references/troubleshooting.md §L1, §L2.
HINT_L8
fi

# L9: mosh-server discoverable via SSH command-exec — verify-tier1 item 9
if grep -q '9) mosh-server discoverable' "${TMP_OUT}" && grep -A1 '9) mosh-server discoverable' "${TMP_OUT}" | grep -q FAIL; then
  cat <<'HINT_L9'

L9 — mosh-server SSH-discoverable FAIL (silent-fallback to plain SSH):
  Symptom: Termius shows "mosh, user@host" tag, but Mac has no mosh-server
  process during the session. Connection works but mosh benefits (roaming,
  sleep resilience) are absent — the client silently fell back to SSH.

  Root cause: SSH command-exec PATH on macOS is /usr/bin:/bin:/usr/sbin:/sbin
  only. Apple Silicon Brew installs mosh-server at /opt/homebrew/bin, which
  is not on that PATH. ~/.zprofile is NOT enough — it loads only for login
  shells; SSH command-exec uses non-interactive non-login shells which read
  ~/.zshenv instead.

  Fix:
    cp templates/zshenv.template ~/.zshenv
    # If ~/.zshenv already exists, merge the brew-shellenv block manually.

  Verify:
    ssh -i ~/.ssh/id_ed25519_mobile <user>@127.0.0.1 'command -v mosh-server'
    # → /opt/homebrew/bin/mosh-server  (was empty before fix)

  See references/troubleshooting.md §L3.
HINT_L9
fi

# Termius 📱 窓 (iOS-side advisory — always shown)
cat <<'HINT_TERMIUS'

📱 Termius (iOS-side advisory — always shown):
  - Termius cannot be inspected from the Mac. If Mosh is not an option in
    the Termius Host edit screen, your Free-tier may no longer include Mosh.
  - Fallback: use plain SSH + tmux attach. Add 'ssh user@host -t "tmux attach"' as a Termius snippet.
  - Alternative client: install Moshi (Free) on iOS as Secondary.
  See references/troubleshooting.md §L7 and references/setup-tier1.md §4.
HINT_TERMIUS

echo
echo "══════════════════════════════════════════════════════════════════════"
if [ "${VERIFY_EXIT}" -eq 0 ]; then
  echo " Doctor result: HEALTHY (warnings may still exist)"
else
  echo " Doctor result: NEEDS ATTENTION — see remediation hints above"
fi
echo "══════════════════════════════════════════════════════════════════════"
exit "${VERIFY_EXIT}"
