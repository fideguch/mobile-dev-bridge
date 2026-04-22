# Contributing

mobile-dev-bridge は個人運用のスキルですが、他の人が fork / PR しやすいように方針を明記しておく。

## 運用モード

- **Solo maintainer**: fideguch (2026-04-22 時点)
- **Review flow**: main 直 push 可。ただし `scripts/*.sh` の変更時は `shellcheck` CI が PASS すること (GitHub Actions で自動)
- **Branch strategy**: Trunk-based (main)、例外的に複数 Phase を並行する場合のみ `feat/phase-N-xxx` を切る

## PR を送る場合

1. Fork → feature branch を切る
2. `shellcheck scripts/*.sh` をローカルで PASS させる
3. 変更対象が `SKILL.md` のフロントマターの場合、`install.sh` → 起動テストで壊れないことを確認
4. `CHANGELOG.md` に Unreleased section を追加
5. PR 作成時: 変更理由 (why) + 検証手順 (how to verify) を本文に記載
6. レビュー方針: 緊急性より再現性を優先。実機検証なしの merge は拒否 (HARD-GATE #4)

## コミットメッセージ

Conventional Commits を推奨:

```
feat: add Tier 2 code-server setup script
fix(install): handle existing ~/.tmux.conf by backing it up first
docs(readme): clarify Termius Free tier Mosh caveat
chore(ci): pin shellcheck version
```

## HARD-GATE 違反になる変更

以下はレビューで必ず reject:

- `scripts/*.sh` のデフォルトが `--apply` 相当になる変更 (HG-GATE #1 違反)
- `.env` / Stripe / Supabase key を touch するコード (HG-GATE #3 違反)
- 有料アプリ購入を自動化する変更 (HG-GATE #6 違反)
- webhook payload に Claude プロンプト本文を含める変更 (HG-GATE #5 違反)

## テスト

Phase 1 時点ではテスト harness なし。`shellcheck` のみ CI で走る。
Phase 2 以降で `tests/` に E2E smoke を追加予定。

## 質問

Issue を立てる前に:
- `references/troubleshooting.md` を一度読む
- `./scripts/doctor.sh` を走らせる
- それでも解決しなければ Issue で症状 + doctor.sh 出力を貼る
