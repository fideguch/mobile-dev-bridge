# HANDOFF — Session-to-Session State

このファイルは「次にこのリポに触る人 (未来の自分 or 他セッション) が 30 秒で現状を把握する」ためのメモ。
長文メモは別ファイル (CHANGELOG / SECURITY / references/) に切り出して、ここには **今どこまで進んで、次に何をやるか** だけ書く。

---

## v0.2.0 (2026-04-22) — **Phase 1 完全完了** ✅

全 forge_ace ゲート PASS + gatekeeper HG-5 実機検証 PASS + PQG 残課題 (Termius Free Mosh) 解決。
Phase 1 MVP は production-ready、次は Phase 2 以降の拡張。

### 完了した Phase 1 DoD

- [x] 独立 Git リポジトリ `~/mobile-dev-bridge/` 初期化 + GitHub `fideguch/mobile-dev-bridge` public 連携
- [x] Claude Code シンボリックリンク (`~/.claude/skills/mobile-dev-bridge`)
- [x] スキル本体 (SKILL.md / README.md / README.en.md / QUICKSTART / SECURITY / CONTRIBUTING / CHANGELOG / LICENSE)
- [x] scripts/ (install-tier1 / verify-tier1 / doctor)
- [x] references/ (setup-tier1 / security / troubleshooting)
- [x] templates/ (tmux.conf)
- [x] CI (.github/workflows/shellcheck.yml)
- [x] **forge_ace Full**: Writer → Guardian → Overseer(full) → PM-Admin(full) → Designer 全 PASS
- [x] **gatekeeper HG-5 実機検証 PASS** (2026-04-22, iPhone 15 + MacBook)
  - Mac 側 verify-tier1.sh: 5 PASS / 0 FAIL / 1 WARN (caffeinate は Phase 2)
  - iPhone → Mac 接続: ✅ SSH mode + ✅ **Mosh mode 両方成功**
  - tmux `main` auto-attach: ✅ 動作
  - Claude Code CLI: ✅ v2.1.117 起動・対話応答
- [x] **PQG condition #1 解決**: Termius Free tier で **Mosh が動く事実を実機で確認**

### 次にやること (Phase 2 以降)

- **Phase 2**: caffeinate LaunchAgent 自動化 + Claude iOS `remote-control` 連携
- **Phase 3**: code-server (Tier 2) 対応
- **Phase 4**: Moshi webhook / Upgrade サイクル確立

---

## Termius Free + Mosh verification log (PQG condition #1) — ✅ RESOLVED

**PQG 指示**: Termius 公式から Mosh サポートが Free tier にあるか独立検証し、結果をここに記録せよ。

### 2026-04-22 独立検証 (Phase 1 前)

- 実行: `WebFetch https://termius.com/pricing`
- 結果要約: **Termius 公式 pricing ページには Free tier の Mosh サポートが明示されていない。** Starter (Free) に列挙されている機能は「SSH and SFTP, Local vault, AI-powered autocomplete, Port Forwarding」。Mosh は feature table のどの tier にも明示的には出てこない。
- 結論: **計画書 v2.1 §1-2 の「Mosh は Free tier で動く」前提は、公式 pricing ページだけでは確認できなかった**

### 2026-04-22 実機検証 (Phase 1 DoD) — ✅ 結論: Free tier で Mosh 動作する

実機環境:
- **Mac**: macOS / `fideguch.tail84e2f5.ts.net` / tailscale 1.96.5 / mosh 1.4.0 / tmux 3.6a
- **iPhone**: iOS (iPhone 15 系) / 5G / Termius Free tier (アカウント `0000fumito@gmail.com`)
- **接続**: Tailscale P2P (WireGuard) 経由、Mac と iPhone は同一 Tailscale アカウント

検証ステップと結果:
1. ✅ Termius で Host 作成 (Address: `fideguch.tail84e2f5.ts.net`, Port: 22, SSH key: Termius 生成 ed25519 `iphone-mobile`)
2. ✅ **Use SSH: ON** → 接続成功、tmux `main` auto-attach、Claude Code 起動・対話応答
3. ✅ **Use Mosh: ON** → **接続成功、コマンド実行問題なし**
4. ✅ 結論: **Termius Free tier で Mosh は使える** (2026-04-22 現在)

### 判定

**計画書 v2.1 の「Termius Free tier = Primary, Mosh 込み」前提を実機で確定。Moshi (Secondary) への移行不要。**

公式 pricing ページに明示されていないが、Free tier でも Mosh の接続ピッカーが出現し、動作確認済。Termius の pricing 表示は Pro 機能 (SFTP / Cloud sync) を際立たせる設計で、Mosh は全 tier 共通機能と推定。

### 今後のリスク

- Termius が将来 Mosh を Pro 限定に変更した場合 → Moshi Free へ即移行 (references/migration-termius.md 予定 / Phase 4)
- 当面の監視: 年 1 回 Upgrade モードで termius.com/pricing を再確認

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

Phase 1 実機検証中に気づいた摩擦を記録。次 Phase の改善材料。

| 日付 | 場面 | 摩擦 | 提案 |
|------|------|------|------|
| 2026-04-22 | Step A-2 `sudo tailscale up` | `brew install tailscale` は **CLI のみ**、daemon/GUI は別途必要。`failed to connect to local Tailscale service` エラー | `install-tier1.sh` で `brew install --cask tailscale` or App Store 版を案内追加 (Phase 1.1 polish) |
| 2026-04-22 | Step A-3 `sudo systemsetup -setremotelogin on` | macOS 13+ で **Full Disk Access** 権限要求、ターミナルが権限持たず失敗 | QUICKSTART/setup-tier1 に「System Settings GUI で Sharing → Remote Login ON」を先に案内 |
| 2026-04-22 | Step 4 verify-tier1.sh L2 (mosh-server) | `head -1 \| grep -q 'MOSH CONNECT'` が flush タイミング依存で flaky (私の Bash 環境 3/3 PASS, ユーザー zsh/cmux 環境 FAIL) | **修正済 v0.1.2 commit `6788b87`**: `head -8` + 全行 grep に変更、3/3 PASS 確認 |
| 2026-04-22 | Step B-5 Termius Address 入力 | `http://` プレフィックスを含めて入力してしまい `Address resolution finished with error: unknown node or service` | QUICKSTART に「❌ http:// 不要、末尾ドット不要」の明示警告 (Phase 1.1) |
| 2026-04-22 | Step B-2 Tailscale アプリ | ユーザーが **Termius と Tailscale を混同**、Termius スクショ貼って来た | QUICKSTART 冒頭に「Tailscale と Termius は別アプリ」の説明 + アイコン描写追加 |
| 2026-04-22 | heredoc コピペ | Claude の出力に含まれるインデント付き `EOF` が heredoc 終了マーカーとして認識されず shell hang | printf 版の代替コマンド提示。Assistant 側の改善 (インデント無しブロック or `<<-'EOF'` tab-only) |
| 2026-04-22 | Tailscale client/server version mismatch warning | brew CLI `1.96.4` vs cask/App Store GUI daemon `1.96.5` で warning 出る (動作は問題なし) | README で「warning は無視可」を記載、install-tier1.sh で一元化する案 (Phase 2) |

---

## Known Issues / Postmortem Candidates

Phase 1 で実際に起きた障害の記録 (全て解決済)。

| issue | first seen | root cause | status |
|-------|-----------|-----------|--------|
| verify-tier1.sh L2 mosh-server test flaky | 2026-04-22 Phase 1 HG-5 | stdout(MOSH CONNECT)/stderr(version banner) merge の flush 順依存 | ✅ RESOLVED (commit 6788b87, v0.1.2) |
| Termius Free tier Mosh 動作未確認 | 2026-04-22 PQG review | termius.com/pricing に明示なし | ✅ RESOLVED (実機で Free tier Mosh 動作確認) |
| Tailscale brew CLI + GUI daemon 分離 | 2026-04-22 Phase 1 HG-5 | brew formula tailscale は CLI のみ、daemon は別必要 | ⚠️ DOCUMENTED (Phase 1.1 で install-tier1.sh 改善予定) |

---

## Phase 2 以降の memo (先走り defer)

- Claude iOS app `remote-control` の最新実装確認 (`claude --help` で subcommand 有無を見る)
- `caffeinate` LaunchAgent の plist 自動生成 (Phase 2 で `scripts/setup-caffeinate-launchd.sh` 追加)
- Moshi Free tier の動作確認 (Secondary として保持)
- Tailscale MagicDNS の hostname 固定化手順
- `ssh-config-snippet.template` の追加 (Phase 2, ユーザーの `~/.ssh/config` に貼る用)

これらは **今はやらない**。Phase 1 実機検証が PASS してから手を付ける。
