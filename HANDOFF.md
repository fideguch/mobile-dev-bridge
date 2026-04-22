# HANDOFF — Session-to-Session State

このファイルは「次にこのリポに触る人 (未来の自分 or 他セッション) が 30 秒で現状を把握する」ためのメモ。
長文メモは別ファイル (CHANGELOG / SECURITY / references/) に切り出して、ここには **今どこまで進んで、次に何をやるか** だけ書く。

---

## v0.1.0 (2026-04-22) — Phase 1 MVP scaffold 完了

### 完了した Phase 1 タスク

- [x] 独立 Git リポジトリ `~/mobile-dev-bridge/` 初期化
- [x] GitHub 連携 (`fideguch/mobile-dev-bridge`, public, 最初から公開)
- [x] Claude Code シンボリックリンク (`~/.claude/skills/mobile-dev-bridge`)
- [x] `SKILL.md` フロントマター + モードルーター
- [x] `install.sh` / `uninstall.sh`
- [x] `scripts/install-tier1.sh` (dry-run default, VERSIONS 定数化)
- [x] `scripts/verify-tier1.sh` (6 項目チェック)
- [x] `scripts/doctor.sh` (6 層診断)
- [x] `references/setup-tier1.md` / `references/security.md` / `references/troubleshooting.md`
- [x] `templates/tmux.conf.template`
- [x] `.github/workflows/shellcheck.yml`
- [x] forge_ace Full の Writer step 完了。Guardian / Overseer / PM-Admin / Designer は次のセッションで実施

### 未完了 — 次にやること (優先順位順)

1. **[Phase 1 DoD #1] 実機検証 (gatekeeper HG-5)**: 実 iPhone + MacBook で `install.sh` → `verify-tier1.sh` が 15 分以内で PASS するか
2. **[PQG condition #1] Termius Free tier の Mosh サポート確認**: 下記 "Termius Free + Mosh verification log" を埋める
3. **[forge_ace残り]** Guardian / Overseer / PM-Admin / Designer の 4 ゲートを通す
4. **[Phase 1 DoD #3]** README.md QUICKSTART を別メンバー 1 人が詰まらず読めるかレビュー

---

## Termius Free + Mosh verification log (PQG condition #1)

**PQG 指示**: Termius 公式から Mosh サポートが Free tier にあるか独立検証し、結果をここに記録せよ。

### 2026-04-22 時点の独立検証結果

- 実行: `WebFetch https://termius.com/pricing`
- 結果要約: **Termius 公式 pricing ページには Free tier の Mosh サポートが明示されていない。** Starter (Free) に列挙されている機能は「SSH and SFTP, Local vault, AI-powered autocomplete, Port Forwarding」。Mosh は feature table のどの tier にも明示的には出てこない。
- 結論: **計画書 v2.1 §1-2 の「Mosh は Free tier で動く」前提は、公式 pricing ページだけでは確認できなかった**
- 対処: `references/setup-tier1.md` に「Termius Free + Mosh 検証」セクションを追加し、`2026-04-22 時点で termius.com/pricing に明示なし、初回 Phase 1 実機テスト時に確認` の旨を記載済み
- 次にやること: Phase 1 実機検証時 (gatekeeper HG-5) に、実 iPhone の Termius Free tier で Mosh が接続ピッカーに出るかを確認 → 結果をここに追記

### 想定される 3 パターン

| 実機結果 | 判断 |
|---------|-----|
| Free tier で Mosh 接続が動作する | そのまま Termius Free を Primary として確定 |
| Free では SSH のみ、Mosh は Pro | Moshi Free (Secondary) に Primary を切替、もしくは plain SSH + tmux でフォールバック |
| Mosh が完全廃止されている | 計画書を改訂、Blink/Moshi/他を再評価 |

---

## Next session starter

次セッション開始時に最初に読むべきもの:

```bash
cd ~/mobile-dev-bridge
cat HANDOFF.md                              # この文書
cat CHANGELOG.md                            # v0.1.0 で何が入ったか
cat references/setup-tier1.md               # Termius Free + Mosh 検証節
gh repo view fideguch/mobile-dev-bridge     # GitHub 側の状態
./scripts/doctor.sh                         # 自分の Mac で状態確認 (non-destructive)
```

---

## Observations / Friction Log

Phase 1 実機検証中に気づいた摩擦をここに記録 (最初は空、気づいたら追加)。

| 日付 | 場面 | 摩擦 | 提案 |
|------|------|------|------|
| — | — | — | — |

---

## Known Issues / Postmortem Candidates

実機で再現する障害をここに記録。失敗が起きたら行を追加。

| issue | first seen | root cause hypothesis | status |
|-------|-----------|----------------------|--------|
| — | — | — | — |

---

## Phase 2 以降の memo (先走り defer)

- Claude iOS app `remote-control` の最新実装確認 (`claude --help` で subcommand 有無を見る)
- `caffeinate` LaunchAgent の plist 自動生成 (Phase 2 で `scripts/setup-caffeinate-launchd.sh` 追加)
- Moshi Free tier の動作確認 (Secondary として保持)
- Tailscale MagicDNS の hostname 固定化手順
- `ssh-config-snippet.template` の追加 (Phase 2, ユーザーの `~/.ssh/config` に貼る用)

これらは **今はやらない**。Phase 1 実機検証が PASS してから手を付ける。
