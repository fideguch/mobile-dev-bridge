# Troubleshooting — 9-Layer Diagnostic

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

### 症状: verify-tier1.sh 7) FAIL — Remote Login OFF

`verify-tier1.sh` 項目 7 (`TCP/22 reachable on 127.0.0.1`) が FAIL した場合、Mac の Remote Login が OFF になっている。**iPhone からの接続試行は全部 silent fail する** (Tailscale も鍵も問題なくても、入口が閉まっている状態)。

GUI で確実に直す:

```
System Settings → 一般 → 共有 → リモートログイン = ON
```

CLI でも可能だが macOS 13+ では Terminal に Full Disk Access 権限がないと `sudo systemsetup -setremotelogin on` が無言で失敗するため、GUI を推奨:

```bash
sudo systemsetup -getremotelogin       # On / Off の確認
sudo systemsetup -setremotelogin on    # FDA 必要、失敗時は GUI へ
```

**macOS の launchd 仕様の罠**: macOS の sshd は launchd が on-demand で spawn するため、アイドル状態では `pgrep sshd` に出てこない。port 22 は実際に接続が来た時だけ開く。「sshd プロセスが見えない=落ちている」と早合点しないこと。判定は `nc -z 127.0.0.1 22` の方が正確。

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

### 症状: Termius が Mosh ラベルでも mosh-server プロセスが起動しない (silent SSH fallback)

**症状**: Termius の Host 詳細画面に「mosh, user@host, osx」のタグが出ている。接続は成功し、コマンドも実行できる。**しかし接続中の Mac で `pgrep mosh-server` を打っても何も出ない**。`lsof -iUDP:60000-61000` も空。SSH に silent fall back している状態で、mosh の本来の利点 (ネットワーク切替時の roaming, スリープ復帰の resilience) が効いていない。

**根本原因**: SSH の command-exec モード (`ssh user@host -- some-command`) で macOS が用意する PATH は `/usr/bin:/bin:/usr/sbin:/sbin` のみ。Apple Silicon の Homebrew は `mosh-server` を `/opt/homebrew/bin/mosh-server` に置くため、SSH 越しの mosh client が `mosh-server` を探しに来た時に見つからず、自動的に plain SSH にフォールバックする。

**`~/.zshenv` vs `~/.zprofile` の罠**:
- Homebrew のインストーラーは `eval "$(brew shellenv)"` を `~/.zprofile` にデフォルトで書く
- `~/.zprofile` は **login shell 専用** のロードファイル
- SSH command-exec は **non-interactive non-login** shell を使うため `~/.zprofile` を読まない
- non-interactive non-login shell が読むのは `~/.zshenv` のみ
- → `~/.zprofile` だけでは PATH が継承されず、mosh-server が見つからない

**修正手順**:

```bash
# テンプレートをコピー (新規作成)
cp ~/mobile-dev-bridge/templates/zshenv.template ~/.zshenv

# 既に ~/.zshenv が存在する場合は中身をマージ:
cat ~/mobile-dev-bridge/templates/zshenv.template >> ~/.zshenv
```

**検証**:

```bash
# 自分の Mac に SSH して mosh-server の解決を確認
ssh -i ~/.ssh/id_ed25519_mobile $(id -un)@127.0.0.1 'command -v mosh-server'
# 修正前: (空文字)
# 修正後: /opt/homebrew/bin/mosh-server
```

**参考**:
- [Mosh issue #237 — fall-back-to-ssh](https://github.com/mobile-shell/mosh/issues/237)
- [Homebrew Discussion #1307 — shellenv loading](https://github.com/orgs/Homebrew/discussions/1307)
- [Moshi docs — fix-mosh-fallback-ssh-macos](https://getmoshi.app/articles/fix-mosh-fallback-ssh-macos)

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

## L6 — caffeinate LaunchAgent (Mac sleep guard, Phase 1.5)

Mac が sleep すると iPhone からの SSH/mosh は全滅する。Phase 1.5 で LaunchAgent 自動化済み。

### 症状: verify-tier1.sh の 6) で FAIL

```bash
./scripts/setup-caffeinate-launchd.sh --status   # 状態確認
./scripts/setup-caffeinate-launchd.sh --apply    # 未インストールなら入れる
pmset -g assertions | grep 'caffeinate.*asserting forever'
# 3 行出れば OK:
#   PreventUserIdleSystemSleep / PreventSystemSleep / PreventDiskIdle
# display 系は含まれない (-d 未使用、ヘッドレス SSH 用途で display 抑制は不要)
```

### 症状: `launchctl bootstrap` が silent に失敗 (exit 0 だが load されない)

plist に `com.apple.quarantine` xattr が付いている (Sonoma/Sequoia の典型事故)。macOS が外部ダウンロード・tar 展開・AirDrop などで受け取ったファイルに付ける検疫属性で、**`launchctl bootstrap` はこの属性が付いていても明示的エラーを出さず silent fail する**。対処:

```bash
xattr -c ~/Library/LaunchAgents/com.mobile-dev-bridge.caffeinate.plist
./scripts/setup-caffeinate-launchd.sh --apply
```

setup script は `xattr -c` を自動実行するので通常は発生しない。手動で plist をエディタで保存し直したり、リポを zip で受け取った場合のみ再現する。

### 症状: LaunchAgent はロード済だが Mac が寝る

まず Apple Silicon + 蓋閉じでないか確認。蓋閉じはハードウェア磁気検知により caffeinate では防げない。
`references/setup-tier1.md` §8-3 参照。対策は AC + 蓋オープン、または外部ディスプレイ接続の clamshell モード。

### 症状: ログに restart loop

```bash
tail -f ~/Library/Logs/com.mobile-dev-bridge.caffeinate.err.log
```

`caffeinate: unrecognized option` が出ていれば古い macOS。macOS 13+ が必須。

### 症状: バッテリー駆動で sleep する

`caffeinate -s` は Apple 公式仕様で**バッテリー時 silently ignored**。AC 接続を前提に運用するか、`-i -m` だけでも idle sleep は防げる。

---

## L7 — Termius config (iOS 側)

Mac からは直接触れない。iPhone 実機で確認すること。

### 症状: Host を開くとすぐ切れる

- Termius → `Settings` → `Log` を有効化 → 再接続 → ログを Mac に AirDrop して確認
- Tailscale アプリが Connected か確認
- Host の Address が MagicDNS ホスト名 (例: `macbook.tail-xxxxx.ts.net`) になっているか

### 症状: Mosh トグルが出ない

→ `references/setup-tier1.md` §4-3 参照。Termius Free tier の仕様変更可能性。

---

## 推測修正禁止 (gatekeeper HG-3 / HG-4)

1. 症状が起きたら **まずログを収集** (サーバログ / mosh stderr / tailscale status / Termius Log)
2. **仮説を立てる前に FACT を並べる**
3. 同じ仮説で 2 回失敗したら **完全に捨てて**別アプローチ
4. 3 回目は新しい切り口を 3 つ列挙してから着手

ルート `SECURITY.md` と `~/.claude/skills/gatekeeper/SKILL.md` 参照。
