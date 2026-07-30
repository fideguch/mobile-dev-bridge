# Setup Tier 1 — Tailscale + Termius + mosh + tmux + LaunchAgent ×2

> Phase 1.7: 自宅 Mac を iPhone / iPad から操作する最小構成 + 24/7 常時起動 + Tailscale 常時接続。
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

> ⚠️ **macOS の Tailscale トグルは sticky**: メニューバーで一度 OFF にする (または `tailscale down` する) と、その状態は**再起動後も永続**する (`WantRunning=false`)。うっかり OFF のまま外出すると iPhone から二度と繋がらない。§12 の watchdog LaunchAgent で必ず自動復旧を仕込むこと。

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
   - **Label**: `MacBook (dev)` など
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

### 6-1. Mac 側 (自動 11 項目チェック)

```bash
./scripts/verify-tier1.sh
```

11 項目すべて PASS が期待値 (項目 6 は §8、項目 10 は §12、項目 11 は §11 の完了後に PASS になる)。

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

## 11. リモートセッションの Full Disk Access (Block F / TCC)

**症状**: iPhone から接続はできるのに、`ls ~/Desktop` / `ls ~/Documents` / `ls ~/Downloads` が `Operation not permitted` になる。ホームディレクトリ直下や `~/mobile-dev-bridge` は読める。

**根本原因**: macOS の TCC (プライバシー保護) は、SSH 経由のリモートセッションに対してデフォルトで保護フォルダ (Desktop / Documents / Downloads / iCloud Drive 等) へのアクセスを拒否する。接続自体は成功するため、他のどの検査項目でも検出できない (2026-07-06 に実運用で顕在化)。

**修正 (GUI のみ — TCC を操作できる公式 CLI は存在しない)**:

```
System Settings → 一般 → 共有 → リモートログイン → ⓘ (情報ボタン)
  → 「リモートユーザーにフルディスクアクセスを許可」= ON
```

反映は**新しい SSH セッションから** — iPhone 側で一度切断して繋ぎ直すこと。

代替 (より狭い許可): System Settings → プライバシーとセキュリティ → フルディスクアクセス → `+` で `/usr/libexec/sshd-keygen-wrapper` を手動追加。

**セキュリティトレードオフ**: この設定は「SSH 鍵が漏れた場合に読める範囲」を広げる。本スキル構成では TCP/22 が Tailscale tailnet 内からしか到達できない (verify 項目 8) ため許容範囲だが、iPhone 紛失時は `SECURITY.md` の鍵ローテーション手順を即実行すること。

**検証**:

```bash
ssh -i ~/.ssh/id_ed25519_mobile $(id -un)@127.0.0.1 'ls ~/Desktop'
# 修正前: ls: .../Desktop: Operation not permitted
# 修正後: ファイル一覧 (または空で正常終了)
./scripts/verify-tier1.sh   # 項目 11 が PASS になる
```

---

## 12. Tailscale 常時接続 watchdog (Block E / sticky toggle-off)

**症状**: caffeinate も sshd も mosh も全部 healthy なのに、iPhone の Tailscale アプリから Mac が **offline (灰色)** に見えて接続できない。Mac 側で `tailscale status` すると `Tailscale is stopped.`。

**根本原因**: macOS の Tailscale は接続トグルの状態 (`WantRunning`) を永続化する。メニューバーからの OFF・`tailscale down`・他 VPN との一時切替などで一度 OFF になると、**再起動してもログインし直しても OFF のまま**。2026-07-06 の実障害では `WantRunning=false, LoggedOut=false` が原因だった (認証は生きているのに接続だけ切れている状態)。

### 12-1. インストール

```bash
# dry-run で内容確認
./scripts/setup-tailscale-watchdog.sh

# 問題なければ適用 (idempotent、再実行安全)
./scripts/setup-tailscale-watchdog.sh --apply
```

これで以下が完了する:

- `~/Library/LaunchAgents/com.mobile-dev-bridge.tailscale-watchdog.plist` 配置
- `launchctl bootstrap gui/$UID` でロード
- `scripts/tailscale-watchdog.sh` が **2 分間隔** (StartInterval 120) で起動
- `BackendState=Stopped` を検出したら `Tailscale up` を実行 → **最悪 2 分で自動復旧**

### 12-2. 動作の詳細

| BackendState | watchdog の動作 |
|---|---|
| `Running` | 何もしない (ログも書かない — 遷移時のみ記録) |
| `Stopped` | `Tailscale up` 実行 (45 秒タイムアウト付き)。素の `up` は既存設定 (accept-routes 等) を保持して `WantRunning=true` だけ立てることを実機検証済み |
| `Starting` / `NoState` | 遷移中 — 次の周期まで待つ |
| `NeedsLogin` / `NeedsMachineAuth` | **自動修復しない** (ブラウザ再認証は人間が必要)。ログに `[NEEDS-HUMAN]` を記録 |
| daemon 応答なし | `open -gja Tailscale` でアプリをバックグラウンド再起動 |

- CLI はアプリ同梱の `/Applications/Tailscale.app/Contents/MacOS/Tailscale` を優先 (daemon とバージョン一致)、なければ PATH の `tailscale`
- **CLI モード強制**: launchd の素の環境 (TERM なし・TTY なし) では app バイナリが GUI モード起動を試み、`The Tailscale GUI failed to start` を出しつつ **exit 0** する (実機確認済み)。plist の `EnvironmentVariables` と script 冒頭の両方で `TAILSCALE_BE_CLI=1` + `TERM=dumb` を設定して回避している
- ログ: `~/Library/Logs/com.mobile-dev-bridge.tailscale-watchdog.log` (512KB で自動ローテーション、healthy tick は無音)
- launchd の `StartInterval` は sleep 中の発火を**スキップ**する (`man launchd.plist` の kevent 制約)。ただし繰り返しタイマー自体は wake 後に再開するため、**wake から最大 120 秒以内に次のチェックが走る** — wake 後の復旧も 2 分以内に収まる

### 12-3. 意図的に Tailscale を切りたい時 (escape hatch)

watchdog は 2 分以内に接続を復元してしまうため、**意図的に** off-tailnet にしたい場合は先に pause する:

```bash
./scripts/setup-tailscale-watchdog.sh --pause 2    # 2 時間 pause (デフォルト 6h)
# ... Tailscale を OFF にして作業 ...
./scripts/setup-tailscale-watchdog.sh --resume     # 早めに戻す (なくても自動復帰)
```

pause は期限付き (`~/.config/mobile-dev-bridge/watchdog.pause` に復帰時刻を記録)。期限が来ると自動で enforcement 再開するので、**pause しっぱなしで翌日繋がらない事故は起きない**。

### 12-4. 状態確認・テスト・アンインストール

```bash
./scripts/setup-tailscale-watchdog.sh --status     # LaunchAgent + pause + BackendState + log tail
./scripts/setup-tailscale-watchdog.sh --run-once   # 今すぐ 1 回チェックを実行
./scripts/setup-tailscale-watchdog.sh --uninstall  # 削除
```

### 12-5. watchdog がカバーしないもの (正直な期待値設定)

| シナリオ | カバー | 補足 |
|---|---|---|
| トグル OFF / `tailscale down` | ✅ 2 分以内に復旧 | Block E 本体 |
| Tailscale.app 落ち / extension 無応答 | ✅ アプリ再起動を試行 | |
| ログアウト状態 (NeedsLogin) | ❌ ログに `[NEEDS-HUMAN]` | ブラウザ再認証は人間のみ。key expiry は Admin Console で端末を「Disable key expiry」にしておくと予防できる |
| Mac の電源 OFF / 蓋閉じ (battery) | ❌ | §8-3 参照 (caffeinate 側の制約)。AC 接続は事実上の必須要件 |
| ログイン前 (login window) | ❌ | watchdog は gui ドメインの LaunchAgent のため、**コンソールにログインするまで動かない**。再起動後に auto-login が無効だと、既存のトグル OFF はログインまで修復されない。常時運用 Mac では auto-login の有効化を検討 (FileVault とは併用不可) |
| FileVault 有効時の再起動直後 | ❌ | pre-boot 画面ではログイン前のため LaunchAgent もネットワークも動かない。物理的にパスワード入力が必要 |
| 停電後の自動復帰 | ❌ | `pmset autorestart` は Apple Silicon MacBook では非対応 (`pmset -g cap` に出ない、実機確認済み)。デスクトップ Mac のみの機能 |
| iPhone 側の表示が stale | ⚠️ | iOS Tailscale アプリが古い peer 状態をキャッシュして「offline」表示することがある。アプリを強制終了→再起動し、mosh/SSH を直接試してから Mac 側障害と判断する |

### 12-6. さらに強くしたい場合 (任意): Tailscale 公式ポリシー層

Tailscale 1.9x には MDM なしでも `defaults` 経由で効く system policy がある (実機の `Tailscale syspolicy list` で `AlwaysOn.Enabled` 等の存在を確認済み)。watchdog と併用すると「クライアント自身が切断を拒否する」層が加わる:

```bash
# 例: 常時接続を強制 (ユーザーがトグル OFF できなくなる)
sudo defaults write /Library/Preferences/io.tailscale.ipn.macsys AlwaysOn.Enabled -bool true
sudo defaults write /Library/Preferences/io.tailscale.ipn.macsys AlwaysOn.OverrideWithReason -bool true
/Applications/Tailscale.app/Contents/MacOS/Tailscale syspolicy reload
/Applications/Tailscale.app/Contents/MacOS/Tailscale syspolicy list   # 反映確認
```

**このスキルが watchdog を主層にしている理由**: (a) sudo 不要で完全にユーザー領域に収まる、(b) `--pause` の柔軟な escape hatch が使える (AlwaysOn は `tailscale down --reason` 必須になる)、(c) ポリシー層はアプリプロセス死・wedge 状態を救えない (watchdog はアプリ再起動も試みる)。ポリシー層は「トグルを物理的に触らせない」運用にしたい場合の追加手段。設定した場合は `sudo defaults delete` で戻せる。MDM 管理下の Mac では競合するので使わないこと。

---

## 13. 参考ソース

- Tailscale iOS docs: https://tailscale.com/kb/1020/install-ios/
- Termius iOS docs: https://support.termius.com/
- mosh (mobile shell) official: https://mosh.org/
- tmux wiki: https://github.com/tmux/tmux/wiki

PM 判断履歴 + Termius Free + Mosh 再確認ログ: `~/mobile-dev-bridge/HANDOFF.md`
