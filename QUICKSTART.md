# QUICKSTART — 5 分で Phase 1 を試す

> 詳しい解説・毎日の使用フロー・モード一覧は [`README.md`](./README.md) を参照。
> このファイルは「迷わず動かす」ための最短経路。

## 前提条件

- macOS Sonoma 以降 / Homebrew インストール済み
- Tailscale アカウント (無料) 作成済み
- iPhone / iPad に Termius (無料) インストール済み
- Mac に SSH 鍵 (`~/.ssh/id_ed25519` または `~/.ssh/id_ed25519_mobile`) 既にある
- Claude Code CLI (`claude`) インストール済み

## Step 1. リポジトリ取得

```bash
git clone git@github.com:fideguch/mobile-dev-bridge.git ~/mobile-dev-bridge
cd ~/mobile-dev-bridge
```

## Step 2. Claude スキルとしてインストール

```bash
./install.sh
```

これで `~/.claude/skills/mobile-dev-bridge` → `~/mobile-dev-bridge` のシンボリックリンクが作成される。
既存リンクがある場合はそのまま上書き (再実行安全)。

確認:

```bash
ls -la ~/.claude/skills/mobile-dev-bridge
# → /Users/you/.claude/skills/mobile-dev-bridge -> /Users/you/mobile-dev-bridge
```

## Step 3. Tier 1 ツールを dry-run で確認

```bash
./scripts/install-tier1.sh
```

出力例:

```
[DRY-RUN] Would run: brew install tailscale
[DRY-RUN] Would run: brew install mosh
[DRY-RUN] Would run: brew install tmux
[DRY-RUN] Would copy templates/tmux.conf.template -> ~/.tmux.conf (no existing file)
```

## Step 4. 実行 (問題なければ)

```bash
./scripts/install-tier1.sh --apply
```

この段階で Homebrew が 3 ツール (Tailscale / mosh / tmux) を入れる。
既存の `~/.tmux.conf` がある場合は `~/.tmux.conf.backup` に退避してから新版が置かれる。

## Step 5. Tailscale をセットアップ (ユーザー操作)

```bash
sudo tailscale up
# → ブラウザが開くので Tailscale アカウントでログイン
tailscale ip -4          # → 自分の Tailscale IP を確認
tailscale status         # → 他デバイスとの接続状態確認
```

## Step 6. iPhone 側 Termius 設定

詳細手順は [`references/setup-tier1.md`](./references/setup-tier1.md) の Section 3-5 を参照。ざっくり:

1. iPhone / iPad で Tailscale アプリをインストールしてログイン
2. Termius アプリを開く → Hosts → Add Host
3. Address: `macbook.tail-xxxxx.ts.net` (Mac で `tailscale status` した時に出たホスト名)
4. Username: Mac のユーザー名
5. Use Mosh: ON (Termius Free tier で Mosh が使えるかは初回検証時に確認)
6. Identity: Mac で作った SSH 鍵を選択 (なければ鍵生成の手順を別途実施)
7. Save → タップして接続

## Step 7. 疎通テスト (6 項目自動チェック)

```bash
./scripts/verify-tier1.sh
```

全項目 PASS なら Phase 1 セットアップ完了。FAIL があれば次へ。

## Step 8. トラブル時

```bash
./scripts/doctor.sh
```

6 層 (Tailscale / SSH / mosh / tmux / Claude CLI / Termius config) の診断と修復提案が出る。
それでも解決しない場合は [`references/troubleshooting.md`](./references/troubleshooting.md) を参照。

---

## よくある詰まりどころ

| 症状 | 対処 |
|------|------|
| `./install.sh: Permission denied` | `chmod +x install.sh && chmod +x scripts/*.sh` |
| `brew install tailscale` が失敗 | `brew update` 実行後にリトライ |
| Tailscale ログインでブラウザが開かない | `sudo tailscale up --login-server=https://controlplane.tailscale.com` |
| Termius で Mosh が選択肢に出ない | Termius Free tier で Mosh サポートが外れた可能性。`references/setup-tier1.md` の「Termius Free + Mosh 検証」節を確認 |
| Mac がスリープで繋がらない | `./scripts/install-tier1.sh --apply` が caffeinate LaunchAgent を入れる (Phase 2 の拡張予定、Phase 1 は手動 `caffeinate -d &` で代替) |

完了すれば、外出先から iPhone で `mosh user@macbook.tail-xxxxx.ts.net` 一発で Mac の tmux に繋がる。
