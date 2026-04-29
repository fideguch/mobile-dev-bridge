# Setup Tier 1 — Tailscale + Termius + mosh + tmux + caffeinate LaunchAgent

> Phase 1.6: 自宅 Mac を iPhone / iPad から操作する最小構成 + 24/7 常時起動。
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

iOS 側 (実機操作、**Termius アプリは既にインストール済み前提**):
- iPhone / iPad に Tailscale アプリをインストール (App Store 無料)
- iPhone / iPad の Termius アプリは既に入っている前提。まだなら App Store → 「Termius」で入れる (30 秒)

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
# sudo 必要: Tailscale の VPN インターフェース (utun) 作成にカーネル権限が要る
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

### 4-2. Termius iOS (Primary クライアント、アプリは既にインストール済み前提)

1. Termius アプリを開く (未ログインなら無料でアカウント作成 or ログイン)
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

### 6-1. Mac 側 (自動 9 項目チェック)

```bash
./scripts/verify-tier1.sh
```

9 項目すべて PASS が期待値。

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

## 8. Mac を寝かせない設定 (Phase 1.5: LaunchAgent で自動化)

**v0.3.0 以降**、手動 `caffeinate -d &` は不要。LaunchAgent が Mac を **24/7 常時起動** に固定する。

### 8-1. インストール

```bash
# dry-run で内容確認
./scripts/setup-caffeinate-launchd.sh

# 問題なければ適用 (idempotent、再実行安全)
./scripts/setup-caffeinate-launchd.sh --apply
```

これで以下が完了する:

- `~/Library/LaunchAgents/com.mobile-dev-bridge.caffeinate.plist` 配置
- `launchctl bootstrap gui/$UID` でロード
- `/usr/bin/caffeinate -i -m -s` が常駐、Mac のログインと同時に自動起動
- 死んだら即 restart (`KeepAlive: {SuccessfulExit: false}`)

### 8-2. フラグ選定の根拠

| フラグ | 意味 | 採用 |
|------|------|------|
| `-i` | idle system sleep 防止 | ✅ |
| `-m` | disk idle sleep 防止 | ✅ |
| `-s` | system sleep 防止 (AC 限定、battery では silently ignored) | ✅ |
| `-d` | display sleep 防止 | ❌ ヘッドレス SSH 用途で display 不要、電力節約のため除外 |
| `-u` | user-active 宣言 (5s タイムアウトあり) | ❌ daemon 用途には誤用 |

### 8-3. ⚠️ Apple Silicon + 閉蓋 は防げない (CRITICAL)

Ventura 以降の Apple Silicon Mac は、蓋を閉じると**ハードウェア磁気検知**で強制 sleep に入る。caffeinate でも pmset でもこれは上書きできない ([Macworld 解説](https://www.macworld.com/article/673295/))。

**対策:**

| 運用形態 | 可否 | 備考 |
|---------|------|------|
| AC 接続 + **蓋オープン** | ✅ | このスキルが想定する標準構成 (Apple Silicon / Intel どちらも OK) |
| Clamshell (蓋閉じ + 外部ディスプレイ + 外部キーボード + AC) | ✅ | Apple 公式サポート構成 (Apple Silicon / Intel どちらも OK) |
| 蓋閉じ + 外部ディスプレイなし | ❌ | Apple Silicon では不可能 (磁気検知で強制 sleep)。Intel は `sudo pmset -a disablesleep 1` で可能だが放熱リスク |
| **Apple Silicon + 蓋オープン + バッテリー駆動** | ⚠️ | `-i -m` は有効で idle sleep は防げる。ただし `-s` は silently ignored なので、長時間放置するとバッテリー切れ or deep sleep に入る可能性あり |
| Intel + 蓋オープン + バッテリー駆動 | ⚠️ | 同上 |

### 8-4. 動作確認

```bash
# LaunchAgent の状態確認
./scripts/setup-caffeinate-launchd.sh --status

# 生の launchctl で確認
launchctl print gui/$(id -u)/com.mobile-dev-bridge.caffeinate

# sleep 防止が効いているか (これが本物の証拠)
pmset -g assertions | grep 'caffeinate.*asserting forever'
```

`asserting forever` の行が **3 行** 出ていれば LaunchAgent 経由の caffeinate が正しく動いている:

| assertion | 由来フラグ | 意味 |
|---|---|---|
| `PreventUserIdleSystemSleep` | `-i` | ユーザー操作無しの idle system sleep 防止 |
| `PreventSystemSleep` | `-s` | system sleep 防止 (AC 限定、battery では silently ignored) |
| `PreventDiskIdle` | `-m` | disk idle spindown 防止 |

`PreventUserIdleDisplaySleep` は **出ない** (`-d` を使っていないため — ヘッドレス SSH 用途で display sleep 抑制は不要、電力節約)。

### 8-5. アンインストール

```bash
./scripts/setup-caffeinate-launchd.sh --uninstall
# 既存の caffeinate プロセスも止めたい場合:
pkill -u "$(id -un)" caffeinate
```

### 8-6. トラブル時

- ログ: `~/Library/Logs/com.mobile-dev-bridge.caffeinate.{out,err}.log`
- `bootstrap` が silent failure する場合: plist の quarantine xattr が原因。`xattr -c ~/Library/LaunchAgents/com.mobile-dev-bridge.caffeinate.plist` で解決 (setup script は自動実行済)
- 詳細: `references/troubleshooting.md` §L6

---

## 9. 完了後

- 外出先から Termius → Host タップ → tmux "main" に入る → Claude Code / next dev がそのまま続く
- 毎日の使用フローは `README.md` の "毎日の使用フロー" 節を参照
- トラブル時は `./scripts/doctor.sh` → `references/troubleshooting.md`

---

## 10. plain SSH フォールバック (UDP ブロック環境用)

キャリア / カフェ Wi-Fi / 社内ネットワークで UDP port 60000-61000 がブロックされている場合、mosh は繋がらない (`references/troubleshooting.md` §L1 参照)。その時は mosh を諦めて plain SSH + tmux attach で代用する。

### Termius 側設定

1. Termius で保存済みの Host を編集 → `Use Mosh` OFF
2. 下部の "Startup Snippet" に以下を貼る:

```bash
tmux attach -t main 2>/dev/null || tmux new -s main
```

3. 保存 → 接続

### 期待される動作

- SSH 接続後すぐ tmux "main" に attach される (無ければ新規作成)
- mosh と違い、電波切れると接続は切れるが、tmux session は Mac 側に残り続ける
- 再接続すれば同じ session に戻れる (tmux が画面保持しているため)

### トレードオフ

| 項目 | mosh | plain SSH + tmux |
|------|------|------------------|
| UDP 必要 | Yes | No |
| 電波切れで切断 | 耐える | 切れる (session は残る) |
| ロール変換遅延 | 低 | 低 |
| タイピング遅延 | 極低 | 低〜中 |

UDP が通る環境に戻ったら `Use Mosh` を ON に戻して良い。

---

## 11. 参考ソース

- Tailscale iOS docs: https://tailscale.com/kb/1020/install-ios/
- Termius iOS docs: https://support.termius.com/
- mosh (mobile shell) official: https://mosh.org/
- tmux wiki: https://github.com/tmux/tmux/wiki

PM 判断履歴 + Termius Free + Mosh 再確認ログ: `~/mobile-dev-bridge/HANDOFF.md`
