# Security Policy

mobile-dev-bridge は自宅 Mac を iPhone から操作する性質上、鍵管理とサプライチェーンの両方で強めの規律を敷く。

## HARD-GATE (計画書 §3-4 準拠)

1. `scripts/*.sh` はデフォルト dry-run、`--apply` を渡さないと破壊的操作しない
2. SSH 鍵 (ED25519) の生成はユーザー手動実行。スキルは `ssh-keygen -t ed25519 -C "..."` の手順提示に限定。自動生成しない
3. `.env` / Stripe / Supabase サービスロールキーにスキルが触れない (読み取り含む禁止)
4. 実機検証 (gatekeeper HG-5) 未完了で「完了」宣言しない
5. **push 通知 / webhook に Claude プロンプト本文を流さない** (Phase 2 以降で webhook を実装する場合もイベント名のみ)
6. 有料アプリを勝手に購入ステップに入れない (Termius Pro / Moshi Pro 含む、ROI を事前にユーザー確認)

## SSH 鍵管理

### 推奨運用

- 鍵タイプ: **ED25519** (RSA は使わない)
- モバイル専用鍵を作る: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_mobile -C "iphone-$(date +%Y%m%d)"`
- iPhone の Termius には **モバイル専用鍵のみ登録** (メイン鍵は Mac に残す)
- `~/.ssh/authorized_keys` で `restrict` オプション付きで制約可能

### 鍵ローテーション (3 ヶ月ごと推奨)

```bash
# 1. 新しい鍵を生成
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_mobile_$(date +%Y%m) -C "iphone-$(date +%Y%m%d)"

# 2. authorized_keys に新鍵を追加 (まだ古い鍵も残す)
cat ~/.ssh/id_ed25519_mobile_$(date +%Y%m).pub >> ~/.ssh/authorized_keys

# 3. Termius で新鍵に切り替え → 接続テスト

# 4. 旧鍵を authorized_keys から削除
# 5. 旧鍵ファイルを安全に削除 (shred 相当で上書き削除)
```

### iPhone 紛失時 (24 時間以内)

1. Tailscale Admin Console から該当端末を削除 (トンネル遮断)
2. Mac 側 `~/.ssh/authorized_keys` から該当鍵の行を削除
3. Stripe / Supabase キーは `.env` にしかないので **自宅 Mac 内に留まる** (iPhone には保存されない設計)

---

## Supply chain (依存ソフトウェアの最小バージョン)

`scripts/install-tier1.sh` が VERSIONS セクションで定数化しているバージョン。セキュリティ脆弱性修正を取り込むための下限。

| ツール | 最小バージョン | 理由 |
|--------|---------------|------|
| Tailscale | `TAILSCALE_MIN=1.80` | WireGuard-go 最新系、2026 年以降の脆弱性修正取り込み |
| mosh | `MOSH_MIN=1.4.0` | locale/UTF-8 ハンドリング改善、ESC シーケンス固定 |
| tmux | `TMUX_MIN=3.4` | `popup`, `display-message -p` 等の最新機能利用 |

### バージョン検証方法

`install-tier1.sh --apply` 実行時に:

```bash
tailscale version    # → 1.80.0 以上
mosh --version       # → 1.4.0 以上
tmux -V              # → tmux 3.4 以上
```

未満の場合は `brew upgrade <pkg>` を提案する (自動実行はしない)。

---

## 脅威モデルと緩和策

| 脅威 | 緩和策 |
|------|-------|
| iPhone 紛失 → Termius 経由で侵入 | iOS 生体認証 + Termius アプリロック + Tailscale 端末削除 + authorized_keys 削除 |
| 公共 Wi-Fi での中間者攻撃 | Tailscale (WireGuard) でエンドツーエンド暗号化、プレーン SSH はフォールバック時のみ |
| Tailscale アカウント乗っ取り | Tailscale 側で MFA 有効化、異常ログインで Magic DNS から即除名 |
| `.env` 漏洩 | HARD-GATE #3 (スキルが touch しない)、commit 前に `git diff --cached` で確認 |
| サプライチェーン攻撃 (brew パッケージ改竄) | 公式 Homebrew tap のみ使用、`brew audit` を年 1 回実行 |
| Claude プロンプト内容の外部流出 | HARD-GATE #5 (webhook はイベント名のみ)、Phase 2 以降も同ルール |

---

## セキュリティ issue 報告

- 公開 issue ではなく、**メールで連絡**: (著者に直接問い合わせ)
- 修正までの目標: CRITICAL=24h / HIGH=7d / MEDIUM=30d
- 重大な脆弱性の場合は 48h 以内に fork して private mirror へ切り替える判断あり

---

## 過去のインシデント

(まだなし。発生したら CHANGELOG.md の `### Security` 節に追記)
