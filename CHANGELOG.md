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
- `tests/`: introduce bats-core smoke tests for install/uninstall/status scripts

### Planned (Phase 2+)
- Claude iOS `remote-control` integration
- code-server (Tier 2) setup references
- Moshi webhook / push notification bridge (event names only)
- Upgrade review protocol (annual)

## [0.3.1] — 2026-04-23 — CI hotfix

### Fixed
- `scripts/verify-tier1.sh`: removed unused `warn()` helper that tripped ShellCheck 0.9.0 (on ubuntu-latest CI) with SC2317 "Command appears to be unreachable". Local ShellCheck 0.11.0 used the different code SC2329, which is why the local pre-push lint missed the CI failure. The function had been retained with a `# shellcheck disable=SC2329` directive in v0.3.0 after the item-6 WARN→FAIL promotion; this release removes it entirely and documents the rationale as a comment. No functional change — `WARN_COUNT` is still emitted in the summary for parser compatibility.

### Notes
- v0.3.0 code is fully functional end-to-end (verify-tier1.sh 6/6 PASS, LaunchAgent loads, pmset shows 3 assertions). The CI failure was a linter-version discrepancy, not a runtime defect.
- Action items recorded for next session: pin ShellCheck version in CI to eliminate local-vs-CI drift.

## [0.3.0] — 2026-04-23 — **Phase 1.5: caffeinate LaunchAgent automation** 🎉

Forward-promoted from Phase 2 due to real-world bug: Mac going to sleep between sessions broke iPhone SSH access. Phase 1 required the user to manually `caffeinate -d &` before closing the lid and lose access whenever they forgot. Phase 1.5 makes Mac "awake 24/7" idempotent and automatic.

### Added
- `scripts/setup-caffeinate-launchd.sh` — idempotent installer with dry-run default + `--apply` / `--uninstall` / `--status` subcommands. Uses modern `launchctl bootstrap gui/$UID` (not deprecated `launchctl load`). macOS 13+ gate. Auto-strips `com.apple.quarantine` xattr (Sonoma+ silent-failure pitfall). Validates rendered plist with `plutil -lint`.
- `templates/com.mobile-dev-bridge.caffeinate.plist.template` — LaunchAgent plist with `__HOME__` placeholder. Conservative flag choice `-i -m -s` (no `-d` — headless SSH doesn't need display sleep prevention; no `-u` — wrong semantics for a daemon). `KeepAlive` as dict (`SuccessfulExit: false`) to avoid restart storms. `ProcessType: Background` hint for power scheduler. Logs to `~/Library/Logs/`.

### Changed
- **BREAKING (minor, permitted by SemVer §4 for 0.x)** `scripts/verify-tier1.sh` — item 6 (caffeinate LaunchAgent) promoted from WARN to **FAIL** when the LaunchAgent is not loaded. Rationale: the LaunchAgent is now a Phase 1.5 gate, and a non-running Mac silently breaks every iPhone connection attempt. SemVer clause: "Anything MAY change at any time. The public API SHOULD NOT be considered stable" (0.x pre-1.0 exception). Users who upgrade from 0.2.0 should run `./scripts/setup-caffeinate-launchd.sh --apply` once to re-green the smoke test.
- `scripts/doctor.sh` — expanded from 6-layer to 7-layer diagnostic with new L6 (caffeinate) and renumbered L7 (Termius). Added remediation block for failed LaunchAgent with launchctl / pmset assertion commands.
- `SKILL.md` — new `Install (caffeinate)` mode in Mode Router. Phase renamed from "Phase 1 DoD" to "Phase 1.5 DoD" (4 criteria, adding reboot persistence).
- `references/setup-tier1.md` §8 — rewritten from "Phase 1 は手動 caffeinate -d &" to full LaunchAgent automation guide with flag rationale table + Apple Silicon lid-close caveat + verify/uninstall commands.
- `references/troubleshooting.md` — §L6 rewritten to caffeinate LaunchAgent remediation; Termius block renumbered to §L7. Title updated from "6-Layer Diagnostic" to "7-Layer Diagnostic".
- `QUICKSTART.md` — new Step 5.5 for `setup-caffeinate-launchd.sh --apply`. Previous "Mac がスリープで繋がらない" row updated to point at the new script.
- `README.md` / `README.en.md` — status line and feature list updated to reflect 24/7 awake via LaunchAgent.
- `.github/workflows/shellcheck.yml` — added `xmllint` plist validation step for every `templates/*.plist*` file.

### Research / design decisions
- Flag choice `-i -m -s` documented against community convention `-dimsu`. Rejected `-d` (headless wastes display power) and `-u` (UI wake trigger, wrong for daemon). Sources: `man caffeinate`, [alwaysBeCaffeinating](https://github.com/thomstratton/alwaysBeCaffeinating), [Jellayy's gist](https://gist.github.com/Jellayy/3d83a9a124b797af797652afe54a2bb7).
- `KeepAlive` dict preferred over bare `true` to prevent restart storms on clean exits. Source: [tjluoma/launchd-keepalive](https://github.com/tjluoma/launchd-keepalive).
- User-level LaunchAgent chosen over LaunchDaemon (no root needed, matches "personal MacBook" operating model). Source: [practicalparanoid.com](https://practicalparanoid.com/mac/prevent-sleep-or-screensaver-on-macos-via-launchd/).
- Apple Silicon lid-closed behavior documented as a known limitation (hardware magnet enforces sleep regardless of caffeinate/pmset on Ventura+). Source: [Macworld](https://www.macworld.com/article/673295/).

### Root-cause of the bug that triggered this release
- **Report** (2026-04-23): iPhone could not connect to Mac via Termius + mosh after closing the previous Claude Code session.
- **Fact collection** (gatekeeper HG-3): `doctor.sh` returned HEALTHY; Tailscale up both ends; fingerprint of authorized_keys matched id_ed25519.pub (not a key issue); HANDOFF.md showed previous-session end-to-end verification including Mosh; `pmset -g log` tail showed Maintenance Sleep loop starting 2026-04-22 14:59, no Wake entry for 2026-04-23 until manual UserWake.
- **Hypothesis** (HG-4): Mac went to deep sleep because the user did not manually `caffeinate -d &` before closing the previous session; no persistent keep-awake mechanism existed in Phase 1. All other candidates (key mismatch, Mosh loss, Tailscale drift) ruled out by direct evidence.
- **Fix**: this release. LaunchAgent removes the manual step.

### Migration guide (0.2.0 → 0.3.0)
```bash
cd ~/mobile-dev-bridge
git pull
./scripts/setup-caffeinate-launchd.sh              # dry-run, inspect
./scripts/setup-caffeinate-launchd.sh --apply      # install LaunchAgent
./scripts/verify-tier1.sh                          # expect 6/6 PASS now
```

### Known limitations (do not report as bugs)
- caffeinate `-s` is silently ignored on battery (Apple spec). On battery, `-i -m` only prevents idle sleep.
- Apple Silicon MacBooks go to hardware-enforced sleep when the lid is closed, regardless of this LaunchAgent. Use AC + lid open, or clamshell mode (external display + keyboard + charger).

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
