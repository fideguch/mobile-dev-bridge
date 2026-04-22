# Setup Tier 1 — Tailscale + Termius + mosh + tmux

> Phase 1 MVP: 自宅 Mac を iPhone / iPad から操作する最小構成。
> 所要時間: 初回 15-20 分 / 2 回目以降 5 分以内。

このドキュメントは **Mac 側** と **iOS 側** の 2 本立てで進む。Mac 側を終わらせてから iOS 側に移ること。

---

## 1. 前提チェック (30 秒)

```bash
# Mac 側
sw_vers                      # macOS Sonoma 以降推奨
brew --version               # Homebrew インストール済み確認
ls ~/.ssh/id_ed25519*        # 既存の ED25519 鍵確認 (なくても下で作る)
claude --version             # Claude Code CLI 動作確認
```

iOS 側 (実機操作):
- iPhone / iPad に Tailscale アプリをインストール (App Store 無料)
- iPhone / iPad に Termius アプリをインストール (App Store 無料)

---

## 2. Mac 側セットアップ (自動部分)

```bash
cd ~/mobile-dev-bridge
./scripts/install-tier1.sh             # 1. dry-run で内容確認
./scripts/install-tier1.sh --apply     # 2. 実際にインストール
```

これで以下が完了する:

- `brew install tailscale mosh tmux` (既存はスキップ)
- `~/.tmux.conf` を `templates/tmux.conf.template` から配置 (既存は `.backup.TIMESTAMP` に退避)
- 最低バージョン警告 (`tailscale>=1.80` / `mosh>=1.4.0` / `tmux>=3.4`)

---

## 3. Tailscale ログイン (Mac)

```bash
sudo tailscale up
```

ブラウザが開くので Tailscale アカウントでログイン。戻ってきたら:

```bash
tailscale status              # 接続しているデバイス一覧
tailscale ip -4               # 自分の Tailscale IPv4
tailscale status | head -1    # MagicDNS ホスト名 (例: macbook.tail-xxxxx.ts.net)
```

MagicDNS ホスト名 (`macbook.tail-xxxxx.ts.net` 相当) は後で iPhone 側で使うので **メモする**。

---

## 4. iPhone / iPad 側セットアップ (手動)

### 4-1. Tailscale iOS

1. App Store で Tailscale アプリを開き、ログイン (Mac と同じアカウント)
2. VPN プロファイル許可を求められたら許可
3. Tailscale アプリ内で「Connect」トグルを ON
4. Mac の MagicDNS ホスト名が一覧に出れば成功

### 4-2. Termius iOS (Primary クライアント)

1. Termius アプリを開く → 新規アカウント作成 or ログイン (無料で OK)
2. `Hosts` タブ → `+` → `New Host`
3. 入力内容:
   - **Label**: `MacBook (kireinavi)` など
   - **Address**: Mac の MagicDNS ホスト名 (例: `macbook.tail-xxxxx.ts.net`)
   - **Port**: 22 (デフォルト)
   - **Username**: Mac のユーザー名 (`whoami` で確認)
   - **Password**: 空のまま (鍵認証を使う)
4. `Save`

### 4-3. Termius Free + Mosh 検証 (PQG condition #1)

> **重要**: 2026-04-22 時点で termius.com/pricing の feature table に **Mosh が明示されていない**。
> Free tier で Mosh が使えるかは、以下の 3 パターンのいずれか。初回実機テストで確認する。

Termius Host 編集画面で以下を確認:

| 確認項目 | 結果 | 判断 |
|---------|------|------|
| `Use Mosh` のトグルが表示される | 表示される | Free tier でも Mosh 利用可。ON にして保存 |
| `Use Mosh` が Pro 限定と表示 | Pro 限定 | Secondary の Moshi Free に切り替え or plain SSH + tmux でフォールバック |
| そもそも Mosh 選択肢が存在しない | 廃止 | `HANDOFF.md` に記録。Moshi Free に Primary 変更を検討 |

いずれの場合も、**確認結果を `HANDOFF.md` の "Termius Free + Mosh verification log"** に追記する。

---

## 5. SSH 鍵ペアのセットアップ

### 5-1. Mac 側: 鍵生成 (なければ)

```bash
# 既存鍵がなければ専用鍵を作る (推奨: モバイル専用で分離)
test -f ~/.ssh/id_ed25519_mobile || \
  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_mobile -C "iphone-$(date +%Y%m%d)"

# 公開鍵を authorized_keys に追加
cat ~/.ssh/id_ed25519_mobile.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

> HARD-GATE #2: このコマンドはユーザーが手動で実行する。スキルから自動実行しない。

### 5-2. iPhone 側: 秘密鍵を Termius にインポート

**方法 A — AirDrop で転送 (推奨):**

1. Mac で `~/.ssh/id_ed25519_mobile` を AirDrop で iPhone に送る
2. iPhone の「ファイル」に保存
3. Termius → Keychain → `+` → `Imported Key` → ファイルから選択
4. Host 編集画面 → `Identity` → 今インポートした鍵を選択
5. Mac に戻って送ったファイルを削除 (Finder のゴミ箱を空にする)

**方法 B — Termius Keychain で新規生成 (Termius 内で鍵ペア生成):**

このスキルの HARD-GATE #2 は「Mac 側で自動生成しない」だけで、iPhone 側で Termius 内部生成するのは OK。
Termius で生成した公開鍵を Mac の `authorized_keys` に貼るだけでよい。

---

## 6. 疎通テスト

### 6-1. Mac 側 (自動 6 項目チェック)

```bash
./scripts/verify-tier1.sh
```

6 項目すべて PASS が期待値。

### 6-2. iPhone 側 (実機)

1. Termius で保存した Host をタップ
2. 「Use Mosh」ON の場合: mosh ハンドシェイクが出て、そのまま Mac のシェルに入る
3. `hostname` / `whoami` / `uname -a` を打ってメインマシンであることを確認
4. `tmux new -s main` で tmux session を作る
5. iPhone のロック → 1 分後に復帰 → Termius に戻ると session が続いていれば OK (mosh の再接続動作)

---

## 7. tmux auto-attach (~/.zshrc に追記)

Mac の `~/.zshrc` に以下を追記しておくと、iPhone から SSH/mosh ログインするたびに自動で tmux "main" にアタッチ:

```bash
if command -v tmux >/dev/null 2>&1 && [ -z "$TMUX" ] && [ -n "$SSH_CONNECTION" ]; then
  tmux attach -t main 2>/dev/null || tmux new -s main
fi
```

`templates/tmux.conf.template` の末尾コメントにも同じスニペットを置いてある。

---

## 8. Mac を寝かせない設定 (Phase 1 は手動)

Phase 1 では `caffeinate` を手動で起動:

```bash
# Mac 側で 1 回実行 (バックグラウンドで走り続ける)
caffeinate -d &
```

蓋を閉じる前に上記を打つ。Phase 2 で LaunchAgent 化する (`scripts/setup-caffeinate-launchd.sh`)。

---

## 9. 完了後

- 外出先から Termius → Host タップ → tmux "main" に入る → Claude Code / next dev がそのまま続く
- 毎日の使用フローは `README.md` の "毎日の使用フロー" 節を参照
- トラブル時は `./scripts/doctor.sh` → `references/troubleshooting.md`

---

## 10. 参考ソース

- Tailscale iOS docs: https://tailscale.com/kb/1020/install-ios/
- Termius iOS docs: https://support.termius.com/
- mosh (mobile shell) official: https://mosh.org/
- tmux wiki: https://github.com/tmux/tmux/wiki

PM 判断履歴 + Termius Free + Mosh 再確認ログ: `~/mobile-dev-bridge/HANDOFF.md`
