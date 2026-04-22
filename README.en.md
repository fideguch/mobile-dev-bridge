# mobile-dev-bridge

> A Claude Code skill that bridges your iPhone/iPad to your Mac dev environment using free tools: Tailscale + SSH + mosh + tmux + Claude Code CLI.

- **Ongoing cost**: $0 / month (all free-tier)
- **Target user**: Individual engineers whose primary machine is a Mac
- **Phase 1 MVP**: Tier 1 stack (Termius Free + Tailscale + mosh + tmux) setup, verification, and diagnostics

For full documentation (including metaphor diagram, daily-use flow, and mode reference), see the **Japanese [README.md](./README.md)**. This English version is intentionally abbreviated for GitHub discovery.

## Target User

Solo developers who use a Mac as their primary workstation and want to continue working from iPhone / iPad (e.g., on a train, at a café) without renting a cloud VM.

## Non-Goals

- Android clients (Termius Android evaluation is deferred to Phase 4)
- Windows / Linux iOS-equivalent clients
- Team SSO / multi-user key management
- Cloud-VM replacements (this skill exists because real MacBooks have the real `.env`, the real git state, and the real Supabase access)

## Status

- **Version**: v0.1.1
- **Phase**: Phase 1 MVP (Tier 1 stack setup, verification, diagnostics)
- **Real-device verification**: pending — see `HANDOFF.md` for the gatekeeper HG-5 checklist

## Quick install

```bash
git clone git@github.com:fideguch/mobile-dev-bridge.git ~/mobile-dev-bridge
cd ~/mobile-dev-bridge
./install.sh                                # create ~/.claude/skills/ symlink
./scripts/install-tier1.sh                  # dry-run first
./scripts/install-tier1.sh --apply          # actually install tailscale + mosh + tmux
./scripts/verify-tier1.sh                   # 6-item smoke test
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
