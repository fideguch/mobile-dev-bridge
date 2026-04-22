# mobile-dev-bridge

> A Claude Code skill that bridges your iPhone/iPad to your Mac dev environment using free tools: Tailscale + SSH + mosh + tmux + Claude Code CLI.

- **Ongoing cost**: $0 / month (all free-tier)
- **Target user**: Individual engineers whose primary machine is a Mac
- **Phase 1.5**: Tier 1 stack (Termius Free + Tailscale + mosh + tmux) + **caffeinate LaunchAgent automation (24/7 awake)**

For full documentation (including metaphor diagram, daily-use flow, and mode reference), see the **Japanese [README.md](./README.md)**. This English version is intentionally abbreviated for GitHub discovery.

## Target User

Solo developers who use a Mac as their primary workstation and want to continue working from iPhone / iPad (e.g., on a train, at a café) without renting a cloud VM.

## Non-Goals

- Android clients (Termius Android evaluation is deferred to Phase 4)
- Windows / Linux iOS-equivalent clients
- Team SSO / multi-user key management
- Cloud-VM replacements (this skill exists because real MacBooks have the real `.env`, the real git state, and the real Supabase access)

## Status

- **Version**: v0.3.0 — **Phase 1.5: caffeinate LaunchAgent automation** 🎉
- **Phase**: Phase 1.5 adds a user-level LaunchAgent that keeps the Mac awake 24/7 via `/usr/bin/caffeinate -i -m -s`, removing the manual `caffeinate -d &` step from Phase 1
- **Flag rationale**: `-i -m -s` instead of the community's `-dimsu` — no `-d` (wastes display power on a headless SSH target), no `-u` (5-second display-wake trigger, wrong semantics for a daemon)
- **Known limit**: Apple Silicon MacBooks enforce hardware lid-close sleep regardless of caffeinate. Use AC + lid open, or clamshell mode with an external display.
- **Real-device verification**: v0.2.0 cleared all forge_ace gates + gatekeeper HG-5 (iPhone 15 + MacBook, 2026-04-22). v0.3.0 LaunchAgent reboot-persistence verification is queued for the next session.
- **Notable finding (v0.2.0)**: Termius Free tier supports Mosh (confirmed on-device; pricing page does not enumerate it).

## Quick install

```bash
git clone git@github.com:fideguch/mobile-dev-bridge.git ~/mobile-dev-bridge
cd ~/mobile-dev-bridge
./install.sh                                     # create ~/.claude/skills/ symlink
./scripts/install-tier1.sh                       # dry-run first
./scripts/install-tier1.sh --apply               # actually install tailscale + mosh + tmux
./scripts/setup-caffeinate-launchd.sh            # dry-run the LaunchAgent installer (Phase 1.5)
./scripts/setup-caffeinate-launchd.sh --apply    # actually install the LaunchAgent
./scripts/verify-tier1.sh                        # 6-item smoke test
```

## HARD-GATE rules

1. `scripts/*.sh` default to dry-run; `--apply` required.
2. SSH key generation is manual (skill provides instructions, not auto-generation).
3. Skill never reads `.env`, Stripe, or Supabase service-role keys.
4. "Setup complete" is never declared without real-device verification.
5. Push notifications / webhooks send event names only — never Claude prompt body.
6. Paid apps are never auto-queued; ROI confirmation with user required.

## License

MIT © 2026 fideguch
