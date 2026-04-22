# Security Reference

> セキュリティ実装の詳細は `../SECURITY.md` (ルート) に集約している。このファイルは `SKILL.md` から on-demand ロードされる時の簡易索引 + HARD-GATE の再掲。

## HARD-GATE 再掲 (計画書 §3-4)

1. `scripts/*.sh` はデフォルト dry-run
2. SSH 鍵生成はユーザー手動実行
3. `.env` / Stripe / Supabase サービスロールキーに触れない
4. 実機検証未完了で「完了」宣言しない
5. webhook / push 通知に Claude プロンプト本文を流さない
6. 有料アプリを勝手に購入ステップに入れない

## 最小バージョン (supply chain)

| ツール | 最小 | 場所 |
|--------|-----|------|
| Tailscale | 1.80 | `scripts/install-tier1.sh` の `TAILSCALE_MIN` |
| mosh | 1.4.0 | `scripts/install-tier1.sh` の `MOSH_MIN` |
| tmux | 3.4 | `scripts/install-tier1.sh` の `TMUX_MIN` |

ルート `SECURITY.md` の「Supply chain」節に理由あり。

## SSH 鍵ローテーション / 紛失時対応

- ルート `SECURITY.md` の「SSH 鍵管理」節参照
- 3 ヶ月ごとのローテーション推奨
- iPhone 紛失時は 24h 以内に Tailscale 端末削除 + `authorized_keys` 行削除

## 脅威モデル

ルート `SECURITY.md` の「脅威モデルと緩和策」節参照。

## インシデント報告

`CHANGELOG.md` の `### Security` セクションに追記すること。
