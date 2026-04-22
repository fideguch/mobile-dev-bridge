# Troubleshooting — 6-Layer Diagnostic

> `./scripts/doctor.sh` の出力とこのファイルを対で読むこと。
> 2 回同じ仮説で失敗したら捨てること (gatekeeper HG-4)。

## L1 — Tailscale

### 症状: `tailscale status` が失敗 / 「not logged in」

| 原因候補 | 対処 |
|---------|------|
| daemon 未起動 | `sudo brew services start tailscale` |
| 未ログイン | `sudo tailscale up` (ブラウザで認証) |
| Admin Console で端末無効化された | https://login.tailscale.com/admin/machines で該当端末を有効化 |
| macOS ネットワーク権限ブロック | System Settings → Privacy & Security → Full Disk Access / Local Network に tailscaled を追加 |

### 症状: MagicDNS ホスト名が解決されない

```bash
tailscale status | grep -i dns
# DNS: false と出ていたら:
tailscale up --accept-dns
```

### 症状: iPhone から Tailscale IP に ping 通るが mosh が UDP で届かない

- キャリアやカフェ Wi-Fi が UDP ブロックの可能性 → `references/setup-tier1.md` §10 の plain SSH フォールバック
- Tailscale Admin Console で該当 exit-node 経由になっていないか確認

---

## L2 — SSH

### 症状: `Permission denied (publickey)`

```bash
# iPhone Termius が使っている鍵の公開鍵を Mac で確認
grep -F "$(pbpaste)" ~/.ssh/authorized_keys
# 一致しなければ authorized_keys に追加
```

権限チェック:

```bash
ls -la ~/.ssh
# 700 ~/.ssh / 600 authorized_keys / 600 id_ed25519* (秘密鍵) のこと
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_ed25519_mobile 2>/dev/null || true
```

### 症状: sshd 自体が落ちている

macOS の場合 `Settings → General → Sharing → Remote Login` を ON にする。コマンドラインからは:

```bash
sudo systemsetup -getremotelogin
sudo systemsetup -setremotelogin on
```

---

## L3 — mosh

### 症状: Termius で Mosh 接続すると「mosh-server not found」

Mac 側で:

```bash
which mosh-server
# /opt/homebrew/bin/mosh-server 等を想定
```

見つからない場合: `./scripts/install-tier1.sh --apply` を再実行。

### 症状: `mosh: Did not find mosh server startup message`

| 原因 | 対処 |
|-----|-----|
| locale 不整合 | `~/.zshrc` に `export LC_ALL=en_US.UTF-8; export LANG=en_US.UTF-8` |
| UDP port 60000-61000 がブロック | Firewall 設定で mosh-server を許可 |
| sshd の SSH ChallengeResponse で引っかかる | `~/.ssh/config` で該当ホストの `PasswordAuthentication no` を明示 |

### 症状: iPhone で mosh が選べない (Termius 側)

→ `references/setup-tier1.md` §4-3 の 3 パターン判定。`HANDOFF.md` に結果追記。

---

## L4 — tmux

### 症状: `tmux: open terminal failed: not a terminal`

→ SSH/mosh 越しで `bash -c tmux new` のように起動していないか。直接 `tmux` で起動する。

### 症状: auto-attach が動かない

```bash
# .zshrc に追記した auto-attach がロードされているか
grep -A 3 'SSH_CONNECTION' ~/.zshrc
# source し直し
exec $SHELL -l
```

### 症状: tmux config が壊れて起動できない

```bash
# 壊れた直前の .backup を戻す
ls -la ~/.tmux.conf.backup.*
cp ~/.tmux.conf.backup.YYYYMMDDHHMMSS ~/.tmux.conf
```

---

## L5 — Claude Code CLI

### 症状: `claude: command not found`

インストール手順: https://docs.anthropic.com/en/docs/claude-code

PATH 再確認:

```bash
echo $PATH
which claude || echo "not in PATH"
# npm 経由なら: npm ls -g | grep claude
```

### 症状: Claude の認証が切れている

```bash
claude auth logout
claude auth login
```

---

## L6 — Termius config (iOS 側)

Mac からは直接触れない。iPhone 実機で確認すること。

### 症状: Host を開くとすぐ切れる

- Termius → `Settings` → `Log` を有効化 → 再接続 → ログを Mac に AirDrop して確認
- Tailscale アプリが Connected か確認
- Host の Address が MagicDNS ホスト名 (例: `macbook.tail-xxxxx.ts.net`) になっているか

### 症状: Mosh トグルが出ない

→ `references/setup-tier1.md` §4-3 参照。Termius Free tier の仕様変更可能性。

### 症状: Mac 側で caffeinate 切れてスリープ

Phase 1 では手動 `caffeinate -d &`。Phase 2 で LaunchAgent 化予定。

---

## 推測修正禁止 (gatekeeper HG-3 / HG-4)

1. 症状が起きたら **まずログを収集** (サーバログ / mosh stderr / tailscale status / Termius Log)
2. **仮説を立てる前に FACT を並べる**
3. 同じ仮説で 2 回失敗したら **完全に捨てて**別アプローチ
4. 3 回目は新しい切り口を 3 つ列挙してから着手

ルート `SECURITY.md` と `~/.claude/skills/gatekeeper/SKILL.md` 参照。
