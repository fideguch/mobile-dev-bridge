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

## [0.4.0] — 2026-04-30 — **Phase 1.6: 本番盲点 2 件の close (Block A: Remote Login + Block D: mosh PATH)**

v0.3.0 の Phase 1.5 (caffeinate LaunchAgent) リリース後、`verify-tier1.sh 6/6 PASS` の状態でも iPhone Termius 接続が機能しない・mosh の利点が効かないという 2 件の本番盲点が顕在化した。Phase 1.6 はこの 2 件を verify/doctor/install/docs 全層で恒久的に close する。

### Added
- `scripts/verify-tier1.sh` — 新規 3 項目を追加して 6→9 項目化:
  - **項目 7**: Remote Login (sshd) が TCP/22 でループバック到達可能か (`nc -z 127.0.0.1 22`)。Block A の検出
  - **項目 8**: Tailscale IPv4 経由で TCP/22 が到達可能か (実際 iPhone が通る経路)。Block A 補強 + Firewall/ACL の検出
  - **項目 9**: SSH command-exec で `mosh-server` が解決できるか (silent SSH fallback の検出)。Block D の検出
- `scripts/doctor.sh` — L7 (sshd FAIL hint)、L8 (Tailscale-path FAIL hint)、L9 (mosh-server discoverability FAIL hint) の grep-conditional 修復ヒントを追加。既存の Termius 助言ブロックは ordinal を外して advisory として常時表示
- `templates/zshenv.template` — `~/.zshenv` 用の brew shellenv テンプレート。`~/.zprofile` ではなく `~/.zshenv` に置く理由をコメントで詳述
- `scripts/install-tier1.sh` — preflight 冒頭に「Step 0: System Settings → 一般 → 共有 → リモートログイン = ON」を必ず printf で表示する advisory ブロックを追加。NEXT heredoc に Step 8 (`cp templates/zshenv.template ~/.zshenv`) を追加

### Changed
- **BREAKING (minor, 0.x SemVer §4 で許容)** `scripts/verify-tier1.sh` バナー: `6-item smoke test` → `9-item smoke test`。`FAIL_COUNT` の意味が拡張されるため、CI/監視で「PASS 数 = 6」を hard-code している外部があれば調整が必要。v0.3.0 で項目 6 を WARN→FAIL に昇格した先例 (CHANGELOG [0.3.0] §Changed) と同種の前進
- `scripts/doctor.sh` バナー: `7-layer diagnostic` → `9-layer diagnostic`、サブ見出しを `Remediation hints (per verify-tier1.sh item)` に修正 (旧: `7 layers — README §0 metaphor` は誤参照だった。README §0 の 6 部構成ハードウェア比喩と doctor のレイヤー数は別概念)
- `references/troubleshooting.md` タイトル: `7-Layer Diagnostic` → `9-Layer Diagnostic`。§L2 に「verify-tier1.sh 7) FAIL — Remote Login OFF」セクションと macOS launchd on-demand-spawn の罠を追記。§L3 に「Termius が Mosh ラベルでも mosh-server プロセスが起動しない (silent SSH fallback)」サブセクションを新設し、Block D の根本原因と修正手順を解説
- `SKILL.md` Phase 1.5 → **Phase 1.6** へ昇格。DoD を 4 項目から 6 項目へ拡張 (旧 #2 を「9 層」に更新、+ 新 #5 sshd reachability、+ 新 #6 mosh-server discoverable)。Mode Router の Verify 行/Troubleshoot 行も「9 項目」「9 層」へ更新
- `README.md` / `README.en.md` 開発ステータス: v0.3.0 → **v0.4.0**、Phase 1.5 → Phase 1.6、「6 項目」「6-item」→「9 項目」「9-item」、「7 層」→「9 層」
- `QUICKSTART.md` タイトル: `5 分で Phase 1.5 を試す` → `5 分で Phase 1.6 を試す`。Step 5.7 (`~/.zshenv` で mosh-server を SSH 経由で見つけられるようにする) を Step 5.5 と Step 6 の間に追加。Step 7 「6 項目自動チェック」→「9 項目自動チェック」、Step 8 「7 層」→「9 層」

### Research / design decisions
- **Block A (Remote Login)** の検出方法: `lsof -iTCP:22 -sTCP:LISTEN` は sudo なしで信頼できない (macOS sshd は launchd-managed on-demand spawn のため idle 中はリスナー登録されない)。代わりに `nc -z` の TCP probe を採用 — port が反応すれば launchd が SSH を spawn して応答する仕様で、user-mode から確実に判定できる
- **Block D (mosh-server PATH)** の修正先: 候補は (a) sshd_config `AcceptEnv PATH` (server-side、sudo 必要、global 副作用)、(b) `/usr/local/bin/mosh-server` symlink (Homebrew アップデートで壊れる)、(c) `mosh --server=PATH` フラグ (Termius iOS UI が露出していない)、(d) **`~/.zshenv` に brew shellenv** — (d) を採用。理由: user-scope、副作用ゼロ、Apple Silicon と Intel Mac 両対応、Homebrew アップデートで壊れない
- **`~/.zshenv` vs `~/.zprofile`**: Homebrew 公式 installer は `~/.zprofile` に書くデフォルトだが、SSH command-exec は non-interactive non-login shell でこれを読まない。`~/.zshenv` は **すべての zsh invocation** で読まれるため、SSH command-exec も継承できる
- 参考文献:
  - [Mosh issue #237 — fall-back-to-ssh on macOS](https://github.com/mobile-shell/mosh/issues/237)
  - [Homebrew Discussion #1307 — shellenv loading](https://github.com/orgs/Homebrew/discussions/1307)
  - [Moshi 2026 article — fix-mosh-fallback-ssh-macos](https://getmoshi.app/articles/fix-mosh-fallback-ssh-macos)

### Root-cause of the bug that triggered this release
- **Report (2026-04-30)**: iPhone Termius の Host 詳細画面に「mosh, user@host, osx」のタグが出ているのに、接続中の Mac で `pgrep mosh-server` が空。`verify-tier1.sh` は 6/6 PASS で healthy 表示。
- **HG-3 facts collection**:
  - `verify-tier1.sh` 6/6 PASS (false green — 既存項目では検出不可能)
  - `lsof -iTCP:22 -sTCP:LISTEN` → 空 (Block A: Remote Login OFF)
  - `ssh -i ~/.ssh/id_ed25519_mobile $(id -un)@127.0.0.1 'which mosh-server'` → 空文字 (Block D: SSH PATH に Homebrew 不在)
- **HG-4 hypothesis**: 2 件の独立した盲点。(A) Remote Login が OFF でも Tailscale/鍵/mosh は全部 healthy に見えてしまう、(B) SSH command-exec で mosh-server が見つからないと client が silent fallback して mosh の利点だけが消える — どちらも `verify-tier1.sh` 旧版では検出不可能
- **HG-5 verification (post-fix)**:
  - `verify-tier1.sh` 9/9 PASS
  - `pgrep mosh-server` → `mosh-server new -s -c 256 -l LANG=en_US.UTF-8` PID あり
  - `lsof -iUDP:60000-61000` → `mosh-server ... UDP 100.95.25.43:60001`
  - `nc -z 100.95.25.43 22` → 即時成功 (Tailscale path も OK)

### Migration guide (0.3.x → 0.4.0)
スクリプト側は pure additive。手動の user 操作 1 ステップが必要:

```bash
cd ~/mobile-dev-bridge
git pull
# 1. Remote Login が ON か GUI で確認
#    System Settings → 一般 → 共有 → リモートログイン
# 2. ~/.zshenv に brew shellenv を入れる (新規なら cp、既存ならマージ)
cp templates/zshenv.template ~/.zshenv
# 既存 ~/.zshenv がある場合は中身を append:
# cat templates/zshenv.template >> ~/.zshenv
# 3. 検証
./scripts/verify-tier1.sh   # 9/9 PASS が期待値
```

### Known limitations (do not report as bugs)
- 項目 7 は `nc -z 127.0.0.1 22` のループバック probe を使う。極端なケースとして、ループバックインターフェースに firewall を効かせている環境では false FAIL する (一般的構成では発生しない)
- 項目 9 は SSH 鍵 + 非空 `authorized_keys` が必要 — 項目 5 が PASS していないと「skip / fail」になる。実装時は項目 5 を先に通すこと

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
