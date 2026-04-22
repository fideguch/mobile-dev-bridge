# Changelog

All notable changes to mobile-dev-bridge will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned (Phase 1.1 polish)
- `install-tier1.sh`: detect brew formula (CLI-only) vs cask/App Store (daemon included) and guide accordingly
- QUICKSTART.md: explicit "Tailscale ≠ Termius" distinction + icon hints
- QUICKSTART.md: explicit "no http:// prefix, no trailing dot in Address" warning
- setup-tier1.md: lead with System Settings GUI path for Remote Login on macOS 13+

### Planned (Phase 2+)
- Claude iOS `remote-control` integration
- code-server (Tier 2) setup references
- Moshi webhook / push notification bridge (event names only)
- Upgrade review protocol (annual)
- `caffeinate` LaunchAgent automation (Phase 2)

## [0.2.0] — 2026-04-22 — **Phase 1 Complete** 🎉

Phase 1 MVP fully validated on real hardware. All forge_ace gates PASS + gatekeeper HG-5 real-device verification PASS + PQG condition #1 (Termius Free Mosh) resolved.

### Verified (on iPhone 15 / iOS + macOS Mac)

- **Tier 1 stack end-to-end**: `iPhone (Termius Free)` → `Tailscale P2P` → `SSH + Mosh` → `MacBook` → `tmux main auto-attach` → `Claude Code CLI v2.1.117 interactive`
- **Termius Free tier supports Mosh** (as of 2026-04-22). PQG condition #1 resolved: official pricing page does not enumerate Mosh, but real-device test confirms Mosh connection picker appears in Free tier and commands execute over Mosh without issue. See HANDOFF.md §Termius Free + Mosh verification log for details.
- `verify-tier1.sh`: 5 PASS / 0 FAIL / 1 WARN (caffeinate — Phase 2 scope)
- tmux `main` auto-attach via `~/.zshrc` SSH-connection hook: verified
- Claude Code CLI starts and responds to prompts inside tmux over Mosh: verified

### Added

- HANDOFF.md §Observations / Friction Log filled with 7 real-world friction points discovered during HG-5
- HANDOFF.md §Known Issues / Postmortem Candidates filled with 3 resolved/documented issues

### Status

v0.2.0 is the first release where Phase 1 Tier 1 is **production-ready for the author's personal use** (not just "on paper"). Phase 1.1 polish items are queued for the next session; Phase 2+ defers remain as planned.

## [0.1.2] — 2026-04-22

### Fixed
- **scripts/verify-tier1.sh**: mosh-server loopback test (layer 2) was flaky on some Macs. The previous `head -1 | grep -q 'MOSH CONNECT'` failed when `2>&1` merged stderr (version banner) ahead of stdout (MOSH CONNECT line) due to flush-timing differences. Replaced with a bounded read of 8 lines followed by a full-output grep, and surfaced the actual first line in the fail message for future debugging. Fix validated via gatekeeper HG-3 (facts first) on affected Mac: 3/3 PASS after fix, 0/3 PASS before.

## [0.1.1] — 2026-04-22

Polish round addressing findings from the 4-agent forge_ace review (Guardian / Overseer / PM-Admin / Designer).

### Changed
- **SKILL.md**: compressed `description` frontmatter (~200 chars) per Guardian M-1; moved overflow guidance into body "When to use / Not to use" section
- **README.md**: corrected gate-status claim and updated Status line to reflect real-device verification still pending; softened SSH key prereq per Designer UX #3
- **README.en.md**: added Target User / Non-Goals / Status sections per PM-Admin M-4
- **QUICKSTART.md**: softened Termius + SSH key prereqs, added `tailscale status` expected-output example with JSON MagicDNS extraction tip, added 4-layer metaphor header, clarified `mosh` command context per Designer UX #1/#2
- **references/setup-tier1.md**: added §10 plain SSH fallback section (UDP-block remediation), added `sudo tailscale up` kernel-permission note, reflected Termius-installed user state
- **references/troubleshooting.md**: §10 cross-ref now resolves (setup-tier1 §10 created)
- **SECURITY.md**: added §Premortem (12-row risk table, v2.1 plan §7 excerpt) per PM-Admin H-1 and §SLO per PM-Admin M-2
- **HANDOFF.md**: added §Observations / Friction Log and §Known Issues / Postmortem Candidates templates per PM-Admin M-1/M-3
- **CONTRIBUTING.md**: replaced `HG-GATE` with `HARD-GATE` (4 sites) per Guardian L-3, added Pre-release checklist with `gh repo view --json` emptiness check
- **.gitignore**: renamed `/tmp/` to `tmp/` with clarifying comment per Guardian M-2
- **scripts/verify-tier1.sh**: documented `set -e` intentional omission per Guardian L-1
- **scripts/doctor.sh**: noted grep-pattern brittleness for future regression test, extended metaphor to L1–L6 remediation headers per Designer LOW-enhancement
- Normalized Japanese "繋ぐ" usage across docs per Designer consistency finding

### Notes
- No code functionality changes. Documentation and comment fixes only.
- HG-5 real-device verification still pending (see HANDOFF.md §Next session starter).

## [0.1.0] — 2026-04-22

v0.1.0 — enables a user to go from a clean Mac to a verified Tier 1 setup in ≤ 15 minutes on paper; real-device verification pending (see HANDOFF.md §Known Issues).

### Added
- `SKILL.md` with YAML frontmatter (name, description, JP + EN triggers) and mode router
- `install.sh` / `uninstall.sh` for Claude Code symlink management (`~/.claude/skills/mobile-dev-bridge`)
- `scripts/install-tier1.sh` — dry-run-default installer for Tailscale / mosh / tmux with pinned minimum versions (TAILSCALE_MIN=1.80, MOSH_MIN=1.4.0, TMUX_MIN=3.4)
- `scripts/verify-tier1.sh` — 6-item smoke test (Tailscale up / mosh-server loopback / tmux session / claude CLI / SSH key / caffeinate LaunchAgent)
- `scripts/doctor.sh` — layered diagnostic wrapping verify-tier1 with remediation hints
- `references/setup-tier1.md` — step-by-step Tailscale + Termius (iOS) + mosh + tmux setup (Japanese)
- `references/security.md` — SSH key management, HARD-GATE enumeration, supply-chain versions
- `references/troubleshooting.md` — 6-layer diagnostic table mapped to doctor.sh exit codes
- `templates/tmux.conf.template` — baseline tmux config (mouse on, 256color, auto-attach snippet)
- `README.md` (Japanese, primary) with 60-second metaphor diagram (🔐🎣📦🤖📱)
- `README.en.md` (English, abbreviated for GitHub)
- `CONTRIBUTING.md` / `SECURITY.md` / `QUICKSTART.md` / `HANDOFF.md`
- `.github/workflows/shellcheck.yml` — CI runs shellcheck on every script push/PR
- `LICENSE` — MIT

### Notes
- Termius Free tier Mosh support: see HANDOFF.md §Termius Free + Mosh verification log for the 2026-04-22 WebFetch result (termius.com/pricing shows no explicit Mosh listing on Free tier).
- Phase 1 intentionally excludes: Claude iOS integration, code-server, Moshi, Pro-tier features.
