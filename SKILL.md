---
name: mobile-dev-bridge
description: iPhone/iPad から Mac の開発環境 (Tailscale + Termius + mosh + tmux + Claude Code CLI) に SSH 繋ぎ、kireinavi-dev 等のローカル開発を継続するためのセットアップ・検証・診断スキル。継続コスト $0。
triggers:
  - "スマホから開発"
  - "iPhone で Claude Code"
  - "Mac をスマホから操作"
  - "モバイル開発環境"
  - "Tailscale セットアップ"
  - "mosh 繋がらない"
  - "Termius 設定"
  - "mobile dev setup"
  - "iphone to mac dev"
  - "tailscale ssh mac"
  - "claude code mobile"
---

# mobile-dev-bridge — Claude Code Skill

> iPhone / iPad から自宅の Mac をそのまま操作するスキル。クラウド VM ではなく本物の MacBook を使う。
> Phase 1.5 は Tier 1 スタック (Termius Free + Tailscale + mosh + tmux) + **24/7 常時起動 LaunchAgent** のセットアップ支援・検証・診断。
> 継続コスト $0 / 月。

## Design principles (PM Operator Stance 採用 — 思想のみ)

- **P1 Outcomes over outputs**: 「実機で iPhone → Mac 15 分でセットアップが通る」を成功指標にする
- **P3 Chain-of-Verification**: scripts の成功ログと独立に、別コマンドで実機状態を検証する
- **P6 Working Backwards**: README.md の「毎日の使用フロー」をゴールに逆算して Phase を切る
- **P10 Antifragile posture**: Termius Free → だめなら Moshi Free → 必要なら Pro と段階的投資
- **P12 LNO triage**: 「面倒だから検証省略」を gatekeeper HG-5 で強制的に禁止

詳細: 計画書 `~/.claude/bochi-data/memos/2026-04-22-mobile-dev-bridge-skill-plan.md` §5-4

---

## HARD-GATE (計画書 §3-4)

1. `scripts/*.sh` はデフォルト dry-run、`--apply` なしで破壊的操作しない
2. SSH 鍵生成はユーザー手動実行、スキルは手順書・検証のみ
3. `.env` / Stripe / Supabase サービスロールキーには触れない
4. 実機検証未完了で「セットアップ完了」宣言しない (gatekeeper HG-5)
5. webhook / push 通知には Claude プロンプト本文を流さない (イベント名のみ)
6. 有料アプリを勝手に購入ステップに入れない

---

## When to use / Not to use

**Use when** ユーザーが以下を発話:
- "スマホから開発" / "iPhone で Claude Code" / "Mac をスマホから操作"
- "モバイル開発環境" / "Tailscale セットアップ" / "mosh 繋がらない" / "Termius 設定"
- "mobile dev setup" / "iphone to mac dev" / "tailscale ssh mac" / "claude code mobile"

**Do NOT use for**:
- Mac 自体のセットアップ全般 (このスキルは「モバイル → Mac」の橋渡しに限定)
- 無関係なネットワーク質問
- 他プロジェクトの forge_ace 実装セッション中 (切り替えは明示承認必須)

---

## Mode Router

自然言語トリガーから以下のいずれかのモードへルーティング:

| Mode | 状態 | 動作 | 関連ファイル |
|------|------|------|------------|
| **Assess** | 初回 or 再評価 | 現環境ヒアリング (Mac 機種 / iOS 機種 / 既存 VPN) → Tier 提案 → shopping list 提示 | `README.md` §0, §1 |
| **Install (Mac)** | ユーザー承認済 | `scripts/install-tier1.sh` を **dry-run で提示** → 承認後 `--apply` 実行 | `scripts/install-tier1.sh` |
| **Install (caffeinate)** | install-tier1 後 | `scripts/setup-caffeinate-launchd.sh` を **dry-run で提示** → 承認後 `--apply` 実行。LaunchAgent 化で 24/7 常時起動 | `scripts/setup-caffeinate-launchd.sh`, `templates/com.mobile-dev-bridge.caffeinate.plist.template` |
| **Install (iOS guide)** | Mac 側完了 | Tailscale iOS / Termius iOS の設定を**手順書形式**で提示 (スキルは iOS 操作不可) | `references/setup-tier1.md` §3-5 |
| **Verify** | install 後 | `scripts/verify-tier1.sh` 実行 → 6 項目チェック (Tailscale up / mosh loopback / tmux / claude CLI / SSH key / caffeinate LaunchAgent) | `scripts/verify-tier1.sh` |
| **Troubleshoot** | エラー発生時 | `scripts/doctor.sh` 実行 → 7 層診断 (Tailscale / SSH / mosh / tmux / Claude CLI / caffeinate / Termius config) → 症状別修復提案 | `scripts/doctor.sh`, `references/troubleshooting.md` |
| **Upgrade** (Phase 4) | 新手法登場時 | Moshi / Claude Code 新機能 / Tailscale 新機能を評価 → 既存構成への影響判定 → 移行判断 | — |

---

## Mode: Assess

ユーザーが「スマホから開発したい」と言った時の初回フロー:

1. 現環境ヒアリング (1 問ずつ):
   - Mac の機種と macOS バージョン
   - iPhone / iPad の機種と iOS バージョン
   - 既存の VPN / リモートアクセスソリューションの有無
   - 主に外出先でやりたい作業 (Claude Code / next dev / git / Supabase)
2. Tier 1 を提案 (Phase 1 範囲)
3. インストール shopping list を提示:
   - Mac: `brew install tailscale mosh tmux`
   - iOS: Tailscale app (無料) + Termius app (無料)
   - Tailscale アカウント作成 (無料)
   - SSH 鍵ペア (ED25519, ユーザー手動生成)
4. ユーザーの承認で Install モードへ

---

## Mode: Install (Mac)

1. `./scripts/install-tier1.sh` を **dry-run** で実行、出力をユーザーに提示
2. ユーザーが OK と言ったら `./scripts/install-tier1.sh --apply` を実行
3. 既存 `~/.tmux.conf` があれば `.backup` に退避し、テンプレートを配置
4. 完了後、次のステップ (Tailscale up + Termius 設定) を案内

**HARD-GATE**: `--apply` なしで絶対に `brew install` を直接実行しない。

---

## Mode: Install (caffeinate)

Phase 1.5 で追加。Mac を 24/7 常時起動状態に固定する LaunchAgent を導入:

1. `./scripts/setup-caffeinate-launchd.sh` を **dry-run** で実行、出力をユーザーに提示
2. ユーザー承認で `./scripts/setup-caffeinate-launchd.sh --apply` 実行
3. `~/Library/LaunchAgents/com.mobile-dev-bridge.caffeinate.plist` を配置し `launchctl bootstrap gui/$UID` でロード
4. flags は `-i -m -s` (idle / disk / system sleep 防止。display sleep は抑制しない = 電力節約)
5. macOS 13 (Ventura) 以降必須 (`launchctl bootstrap` 構文)

**HARD-GATE**: Apple Silicon + 蓋閉じは caffeinate では防げない (ハードウェア磁気検知)。AC + 蓋オープン、または clamshell モード (外部ディスプレイ + キーボード接続) 前提。

**idempotent**: 再実行安全。既存 LaunchAgent は bootout → bootstrap で入れ直し。

---

## Mode: Install (iOS guide)

iOS 側の設定はスキルが直接操作できないため、**手順書を提示するだけ**:

1. `references/setup-tier1.md` §3 (Tailscale iOS)
2. `references/setup-tier1.md` §4 (Termius 初期セットアップ + Mosh 有無確認)
3. `references/setup-tier1.md` §5 (SSH 鍵のコピー)

ユーザーが詰まった場合は Troubleshoot モードへ。

---

## Mode: Verify

`./scripts/verify-tier1.sh` を実行し、6 項目チェック:

1. Tailscale が `up` 状態か (`tailscale status` 成功)
2. mosh-server がローカルホスト経由で起動確認できるか
3. tmux で新規セッションが作れるか
4. `claude --version` が成功するか
5. `~/.ssh/id_ed25519` または `~/.ssh/id_ed25519_mobile` が存在するか
6. caffeinate LaunchAgent がロード済か (**Phase 1.5 GATE: FAIL 扱い**)

全 PASS で「Phase 1.5 セットアップ完了候補」、1 つでも FAIL なら Troubleshoot へ自動ルーティング。

**HARD-GATE**: この時点ではまだ「完了」宣言しない。gatekeeper HG-5 の実機検証 (実 iPhone で mosh 接続) が PASS して初めて DoD 達成。

---

## Mode: Troubleshoot

`./scripts/doctor.sh` を実行し、7 層診断:

| Layer | 検査内容 | 失敗時の見るべきファイル |
|-------|---------|-----------------------|
| L1 Tailscale | `tailscale status`, MagicDNS 解決 | `references/troubleshooting.md` §L1 |
| L2 SSH | 鍵存在、`ssh -v` 疎通、authorized_keys | `references/troubleshooting.md` §L2 |
| L3 mosh | mosh-server binary, UDP port, `mosh` command | `references/troubleshooting.md` §L3 |
| L4 tmux | `tmux -V`, new-session テスト | `references/troubleshooting.md` §L4 |
| L5 Claude CLI | `claude --version`, PATH | `references/troubleshooting.md` §L5 |
| L6 caffeinate | LaunchAgent ロード状態、`launchctl print`, `pmset -g assertions` | `references/troubleshooting.md` §L6 |
| L7 Termius config | (iOS 側は手動確認) | `references/troubleshooting.md` §L7 |

gatekeeper HG-3 (FACTS) / HG-4 (HYPOTHESIS) を踏襲し、2 回同じ仮説で失敗したら別アプローチへ。

---

## gatekeeper 統合

Phase 1 着手時に `~/.claude/skills/gatekeeper/SKILL.md` の HG-1 〜 HG-5 を適用:

- **HG-1 RESEARCH**: forge_ace Writer 着手前に既存自作スキル構造を読み切る + iOS アプリ選定を事実ベースで行う
- **HG-1.5 UX PROTOCOL**: 手順書・エラーメッセージを書く前に UX 思考 (SCREEN / USER GOAL / HAPPY PATH / ERROR PATH / EDGE CASES) を文字化
- **HG-3 FACTS**: 疎通テスト失敗時、推測ではなくログ・実機出力を先に集める
- **HG-4 HYPOTHESIS**: 同じ仮説で 2 回失敗したら完全に捨てる
- **HG-5 VERIFY**: 実機で Tailscale ping / mosh 接続 / tmux attach / claude CLI 起動が全て通るまで「完了」と言わない

環境変数 `GATEKEEPER_SESSION_DIR=/Users/fumito_ideguchi/mobile-dev-bridge` で session を固定可能。

---

## Phase 1.5 DoD (Definition of Done)

1. 別 Mac / 別 iPhone の同構成で `install.sh` → `install-tier1.sh --apply` → `setup-caffeinate-launchd.sh --apply` → `verify-tier1.sh` が 15 分以内で 6/6 PASS する
2. `doctor.sh` が 7 層すべてチェックできる
3. README.md QUICKSTART で初見エンジニア 1 人が詰まらずセットアップできる
4. Mac 再起動後も LaunchAgent が自動復帰し、`pmset -g assertions` に `caffeinate asserting forever` が残っている

---

## References (on-demand load)

| ファイル | 読むタイミング |
|---------|-------------|
| `README.md` | Assess / 全体像把握 |
| `QUICKSTART.md` | Install モードでユーザーに手順を見せる時 |
| `references/setup-tier1.md` | Install (Mac) / Install (iOS guide) 実行中 |
| `references/security.md` | SSH 鍵ローテーションやインシデント対応時 |
| `references/troubleshooting.md` | Troubleshoot モード + doctor.sh と対で |
| `templates/tmux.conf.template` | Install (Mac) の tmux 設定生成時 |
| `templates/com.mobile-dev-bridge.caffeinate.plist.template` | Install (caffeinate) の LaunchAgent 生成時 |
| `HANDOFF.md` | 次セッション開始時の最初 |
| `CHANGELOG.md` | バージョン履歴確認時 |
| `SECURITY.md` | 鍵漏洩 / サプライチェーン確認時 |

Phase 1.5 スコープ外 (Phase 2 以降で追加):

- `references/claude-remote.md` (Phase 2)
- `references/setup-tier2.md` (Phase 3, code-server)
- `references/tunneling.md` (Phase 3)
- `references/moshi-configuration.md` (Phase 4)

---

## Non-goals (Phase 1.5)

- Claude iOS app `remote-control` 連携 (Phase 2)
- code-server セットアップ (Phase 3)
- Moshi webhook / push 通知 (Phase 4)
- Android (Termius) 対応評価 (Phase 4)
- Windows / Linux クライアント対応 (対象外)

## Not this skill's job

- Mac 自体のハードウェア保守
- チーム SSO / マルチユーザー管理
- Claude Code の代替実装 / Tailscale の代替実装
