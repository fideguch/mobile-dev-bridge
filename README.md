# mobile-dev-bridge

> スマホ (iPhone / iPad) から Mac の開発環境をシームレスに操作するための Claude Code スキル。
> Tailscale + SSH + mosh + tmux + Claude Code CLI を無料で組み合わせ、自宅の MacBook をそのままモバイルから叩く。

- **継続コスト**: $0 / 月 (iOS アプリ無料 + Tailscale 無料 + mosh OSS + tmux OSS)
- **対象ユーザー**: Mac 主機で開発する個人エンジニア (初期は本人、将来チーム展開)
- **Phase 1 MVP**: Tier 1 スタック (Termius Free + Tailscale + mosh + tmux) のセットアップ支援・検証・診断
- **品質ゲート**: forge_ace Full + gatekeeper (HG-1 〜 HG-5) でレビュー済

詳細な計画書: `~/.claude/bochi-data/memos/2026-04-22-mobile-dev-bridge-skill-plan.md` (v2.1)

---

## 0. 60 秒でわかる仕組み (メタファー)

このスキルが組み合わせる 6 つの部品を「家」に例えると:

| 部品 | 例え | 実際の役割 |
|------|------|-----------|
| 🔐 **Tailscale** | 「自宅とスマホを結ぶ**秘密の地下トンネル**」 | インターネットを経由せず、MacBook と iPhone を **直接 P2P で結ぶ VPN**。公開 IP 不要、ルーターのポート開放不要、他人は絶対入れない |
| 🗝️ **SSH + ED25519 鍵** | 「トンネルの先にある**鍵付きドア**」 | トンネルを抜けた先で Mac に入るための電子キー。鍵ファイルは iPhone の Secure Enclave に保存 |
| 🎣 **mosh** | 「切れない**魔法のケーブル**」 | 普通の SSH は電波切れた瞬間死ぬ。mosh は **UDP で状態をサーバに持たせる** → 電車のトンネル・Wi-Fi 切替・スリープでも切れない |
| 📦 **tmux** | 「Mac の中にある**画面保存ボックス**」 | 「スマホから見てる画面」と「Mac 本体の画面」を**切り離す**装置。iPhone を閉じても Claude Code は tmux の中で動き続ける |
| 🤖 **Claude Code CLI** | 「ボックスの中の**AI アシスタント**」 | tmux ボックスの中で動いてる Claude。実ファイルシステム (.env, git, Supabase キー) にアクセスできる |
| 📱 **Termius (iOS)** | 「ボックスを覗く**窓**」 | iPhone 側のターミナルアプリ。Tailscale → SSH → mosh → tmux の順に繋ぎ、最終的に Mac の画面を iPhone に表示 |

### 全体像 — 5 層の積み重ね

```
📱 iPhone (Termius)
   │  Tailscale P2P トンネル (WireGuard, 暗号化)
   ▼
🔐 Tailscale MagicDNS (macbook.tail-xxxxx.ts.net)
   │  SSH ED25519 鍵認証
   ▼
🖥️ MacBook (蓋閉じ・AC 接続・caffeinate で起きたまま)
   └─ 🎣 mosh-server (UDP で状態保持)
       └─ 📦 tmux session "main"
           ├─ w0: 🤖 Claude Code CLI
           ├─ w1: npm run dev (HMR)
           └─ w2: supabase start
```

**ポイント**: iPhone は「窓」、実体は MacBook 側で動き続ける。蓋を閉じても `caffeinate` で寝ない。tmux が画面を保持するので、iPhone を閉じても Claude Code は止まらない。

---

## 1. QUICKSTART (5 分で Phase 1 を試す)

**前提**:
- Mac (macOS Sonoma 以降) に Homebrew が入っている
- Tailscale アカウントを持っている (無料)
- iPhone / iPad に Termius がインストール済み (無料)
- SSH 鍵ペア `~/.ssh/id_ed25519` (または `id_ed25519_mobile`) が既にある

```bash
# 1. このリポジトリをクローン
git clone git@github.com:fideguch/mobile-dev-bridge.git ~/mobile-dev-bridge
cd ~/mobile-dev-bridge

# 2. Claude Code スキルとしてインストール (シンボリックリンク作成)
./install.sh

# 3. Tier 1 ツールを dry-run で確認
./scripts/install-tier1.sh
# 出力を読んで問題なければ:
./scripts/install-tier1.sh --apply

# 4. 疎通テスト (6 項目チェック)
./scripts/verify-tier1.sh

# 5. Termius iOS での設定手順はこちらを読む
cat references/setup-tier1.md
```

詳細は [`QUICKSTART.md`](./QUICKSTART.md) を参照。

---

## 2. ファイル構成 (Phase 1 DoD と突き合わせ)

Phase 1 MVP の Definition of Done を満たす最小構成。ファイル点数を明示して、計画書と差分が出ないことを保証する。

| 種別 | 個数 | ファイル | DoD 対応 |
|------|-----|---------|---------|
| ルート文書 | 9 | `README.md` / `README.en.md` / `CHANGELOG.md` / `CONTRIBUTING.md` / `SECURITY.md` / `QUICKSTART.md` / `HANDOFF.md` / `LICENSE` / `SKILL.md` | QUICKSTART が読める (DoD #3) |
| インストーラー | 2 | `install.sh` / `uninstall.sh` | シンボリックリンク作成 (DoD #1) |
| Scripts | 3 | `scripts/install-tier1.sh` / `scripts/verify-tier1.sh` / `scripts/doctor.sh` | 疎通 6 項目 + 診断 6 層 (DoD #1, #2) |
| References | 3 | `references/setup-tier1.md` / `references/security.md` / `references/troubleshooting.md` | iOS/Mac 両側手順 (DoD #3) |
| Templates | 1 | `templates/tmux.conf.template` | tmux 設定 (DoD #1) |
| CI | 1 | `.github/workflows/shellcheck.yml` | shellcheck で即 fail (P8) |
| Tests placeholder | 1 | `tests/.gitkeep` | Phase 2 以降 |

**合計**: scripts=3, references=3, templates=1, root docs=9 — 計画書 §2-1 の Phase 1 スコープと一致。

### Phase 1 で扱わないもの (明示的 defer)

- Claude iOS app `remote-control` 統合 → Phase 2
- code-server (Tier 2) → Phase 3
- Moshi webhook / push 通知 → Phase 4
- 有料アプリ (Termius Pro, Moshi Pro) → Pro ROI 判断後

---

## 3. 毎日の使用フロー (完成後)

```
☕️ カフェで iPhone を開く
  └─ Termius アプリ起動 → 保存済ホスト「MacBook」タップ
     └─ Tailscale が MagicDNS を解決 → WireGuard で P2P 接続
        └─ SSH ED25519 鍵認証 → ~/.zshrc が tmux "main" に auto-attach
           └─ 画面に Claude Code / next dev / supabase start がそのまま出る
              └─ 電車でトンネル入っても mosh が切れない
                 └─ iPhone 閉じても tmux は Mac で動き続ける
                    └─ 翌朝 Termius 再起動 → 瞬時に元の状態に戻る
```

---

## 4. スキルのモード

Claude に自然言語で話しかけると、以下のモードが起動する:

| ユーザーの発話例 | モード | 動作 |
|----------------|--------|------|
| 「スマホから開発したい」「iPhone で Claude Code」 | **Assess** | 現環境ヒアリング → Tier 提案 |
| 「Tailscale セットアップして」 | **Install (Mac)** | `install-tier1.sh` を dry-run 提示 → 承認後実行 |
| 「Termius の設定教えて」 | **Install (iOS guide)** | `references/setup-tier1.md` の iOS 手順を提示 |
| 「スマホから繋がるか確認して」 | **Verify** | `verify-tier1.sh` 実行 → 6 項目チェック |
| 「mosh が切れる」「繋がらない」 | **Troubleshoot** | `doctor.sh` 実行 → 6 層診断 |
| 「新しい手法出てる？」 | **Upgrade** | 最新動向評価 (Phase 4 で実装) |

---

## 5. HARD-GATE (絶対に守るルール)

1. `scripts/*.sh` はデフォルト dry-run。`--apply` なしで実行しない
2. SSH 鍵の生成は手動実行、スキルは手順書と検証に限定
3. `.env` / Stripe / Supabase サービスロールキーには触れない
4. 実機検証未完了の状態で「セットアップ完了」を宣言しない
5. push 通知 / webhook に Claude プロンプト本文を流さない
6. 有料アプリを勝手に購入ステップに入れない

詳細は [`SECURITY.md`](./SECURITY.md) を参照。

---

## 6. 開発ステータス

- **現在**: Phase 1 MVP scaffold 完了 (v0.1.0)
- **次**: Phase 1 実機検証 (gatekeeper HG-5) → Termius Free tier での Mosh 実動作確認
- **将来 Phase**: Claude iOS 連携 (Phase 2) → code-server (Phase 3) → Upgrade サイクル (Phase 4)

引き継ぎ・検証ログ: [`HANDOFF.md`](./HANDOFF.md)
変更履歴: [`CHANGELOG.md`](./CHANGELOG.md)

---

## 7. ライセンス

MIT License (Copyright © 2026 fideguch)

---

## 8. Links

- 英語版 README: [`README.en.md`](./README.en.md)
- 計画書 (SSOT): `~/.claude/bochi-data/memos/2026-04-22-mobile-dev-bridge-skill-plan.md` v2.1
- gatekeeper 仕様: `~/.claude/skills/gatekeeper/SKILL.md`
- forge_ace 仕様: `~/.claude/skills/forge_ace/SKILL.md`
