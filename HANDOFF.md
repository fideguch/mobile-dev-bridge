# HANDOFF — Session-to-Session State

このファイルは「次にこのリポに触る人 (未来の自分 or 他セッション) が 30 秒で現状を把握する」ためのメモ。
長文メモは別ファイル (CHANGELOG / SECURITY / references/) に切り出して、ここには **今どこまで進んで、次に何をやるか** だけ書く。

---

## v0.4.0 (2026-04-30) — **Phase 1.6: 本番盲点 2 件 (Block A/D) close** ✅

v0.3.0 (Phase 1.5) リリース後、`verify-tier1.sh 6/6 PASS` 状態で iPhone から繋がらない・mosh の利点が効かない 2 件の本番盲点が顕在化。Phase 1.6 はこれを verify/doctor/install/docs 全層で close した。

### Phase 1.6 DoD

- [x] `scripts/verify-tier1.sh` に項目 7 (Remote Login TCP/22 reachable on loopback)、項目 8 (Tailscale-IP TCP/22 reachable)、項目 9 (mosh-server discoverable via SSH command-exec) を追加し 9/9 PASS
- [x] `scripts/doctor.sh` に L7 (sshd FAIL hint)、L8 (Tailscale-path FAIL hint)、L9 (mosh-server discoverability FAIL hint) の grep-conditional 修復ヒントを追加。Termius advisory ブロックを ordinal 外して常時表示の助言として降格
- [x] `references/troubleshooting.md` §L2 に「verify-tier1.sh 7) FAIL — Remote Login OFF」セクション + macOS launchd on-demand-spawn の罠を追記
- [x] `references/troubleshooting.md` §L3 に「Termius が Mosh ラベルでも mosh-server プロセスが起動しない (silent SSH fallback)」サブセクションを新設
- [x] `scripts/install-tier1.sh` preflight 冒頭に Step 0 advisory (System Settings → 一般 → 共有 → リモートログイン = ON) を追加。NEXT heredoc に Step 8 (zshenv テンプレート copy) を追加
- [x] `templates/zshenv.template` 新規作成 (`~/.zprofile` ではなく `~/.zshenv` に置く理由を冒頭コメントで詳述)
- [x] `CHANGELOG.md` に [0.4.0] エントリ追加 (Added/Changed/Research/Root-cause/Migration/Known limitations 6 セクション)
- [x] `HANDOFF.md` に本セクション追加
- [x] `SKILL.md` Phase 1.5 → Phase 1.6 へ昇格、DoD 4 → 6 項目に拡張、Mode Router の Verify/Troubleshoot を 9 項目/9 層へ更新
- [ ] **HG-5 実機検証 (次セッション)**: iPhone Termius 再接続 → 接続中の Mac で `pgrep mosh-server` が PID を返す + `lsof -iUDP:60000-61000` が `mosh-server` を返す + `nc -z <TS_IP> 22` 即時成功

### HG-3 facts collection log (本リリースを引き起こした 2026-04-30 不具合報告)

**修正前**:
- `verify-tier1.sh` → `5 pass / 0 fail / 1 warn` → Overall: PASS (false green)
- `lsof -iTCP:22 -sTCP:LISTEN` → 空 (Block A: Remote Login OFF)
- `ssh -i ~/.ssh/id_ed25519_mobile $(id -un)@127.0.0.1 'which mosh-server'` → 空文字 (Block D: SSH PATH に Homebrew 不在)
- iPhone Termius の Mosh タグ表示はあるが、Mac 側で `pgrep mosh-server` 空 → silent SSH fallback

**修正後**:
- `verify-tier1.sh` → 9/9 PASS
- `pgrep mosh-server` → `mosh-server new -s -c 256 -l LANG=en_US.UTF-8` PID あり
- `lsof -iUDP:60000-61000` → `mosh-server ... UDP 100.95.25.43:60001`
- `nc -z 100.95.25.43 22` → 即時成功

### 2 件の root cause (named diagnoses)

1. **Block A: macOS Remote Login Hidden Off** — `verify-tier1.sh` 6/6 PASS でも Remote Login が OFF だと iPhone 接続は全 silent fail。`pgrep sshd` も `lsof` も idle 中は空なので「sshd は動いてない」と勘違いしやすい (実際は launchd on-demand spawn)。GUI の System Settings → 一般 → 共有 → リモートログイン を ON にする以外に確実な方法はない
2. **Block D: SSH command-exec PATH Homebrew Blindness** — Homebrew インストーラーが `~/.zprofile` に `eval $(brew shellenv)` を書くため login shell では PATH が通る。しかし SSH command-exec (mosh の起動経路) は non-interactive non-login shell で `~/.zprofile` を読まない → `mosh-server` が見つからない → mosh client が silent fallback して plain SSH 化。`~/.zshenv` に brew shellenv を置くことで全 invocation 種別をカバー

### HG-5 verify steps for next session

```bash
# 1. verify-tier1.sh が 9/9 PASS を維持しているか
./scripts/verify-tier1.sh
# 期待: [verify-tier1] Summary: 9 pass / 0 fail / 0 warn

# 2. iPhone Termius から MagicDNS 経由で mosh 接続
# 接続中の Mac で:
pgrep mosh-server   # PID が出れば mosh が真に起動している
lsof -iUDP:60000-61000 | grep mosh-server   # UDP リスナーが Tailscale IP に bind しているか

# 3. Block D の独立検証
ssh -i ~/.ssh/id_ed25519_mobile $(id -un)@127.0.0.1 'command -v mosh-server'
# 期待: /opt/homebrew/bin/mosh-server
```

---

## v0.3.0 (2026-04-23) — **Phase 1.5 完了: caffeinate LaunchAgent 自動化** ✅

v0.2.0 デプロイ後、Mac が sleep して iPhone 接続不可になる実問題が発生。Phase 2 予定だった LaunchAgent 自動化を Phase 1.5 として前倒し実装・リリース。手動 `caffeinate -d &` 運用を廃止、LaunchAgent が 24/7 Mac awake を保証。

### Phase 1.5 base DoD

- [x] `scripts/setup-caffeinate-launchd.sh` 新規 (dry-run default / `--apply` / `--uninstall` / `--status`, idempotent, macOS 13+ gate, xattr -c 自動, plutil -lint 自動)
- [x] `templates/com.mobile-dev-bridge.caffeinate.plist.template` 新規 (flags `-i -m -s`, `KeepAlive dict`, Logs to `~/Library/Logs/`)
- [x] `verify-tier1.sh` 項目6 を WARN→**FAIL** に昇格
- [x] `doctor.sh` 7-layer 拡張 (L6=caffeinate, L7=Termius)
- [x] `references/setup-tier1.md` §8 全面書き換え + Apple Silicon 蓋閉じ警告
- [x] `references/troubleshooting.md` §L6 caffeinate 診断追加
- [x] `QUICKSTART.md` Step 5.5 追加 (9 step 構成)
- [x] `SKILL.md` Mode Router に `Install (caffeinate)` 追加 + Phase 1.5 DoD
- [x] CI `.github/workflows/shellcheck.yml` に plist xmllint 検証追加
- [ ] **HG-5 実機検証**: iPhone から Mac 再起動後の再接続テスト (次セッションで確認)

### リサーチ履歴 (v0.3.0 策定時)

- `caffeinate` フラグ: `-dimsu` (community 多数派) → `-ims` (headless SSH 最適化) に改善。`-d` (display) は電力浪費、`-u` は daemon 誤用
- `launchctl load` → `launchctl bootstrap gui/$UID` (macOS 13+ 必須)
- `KeepAlive: true` → `dict {SuccessfulExit: false}` (restart storm 防止)
- LaunchAgent (user) vs LaunchDaemon (root): 個人用は Agent が正解
- Apple Silicon 蓋閉じ: ハードウェア磁気検知で caffeinate 不可 → docs 明示

### v0.2.0 運用で顕在化した問題

**発生日時**: 2026-04-23 (v0.2.0 リリース翌日)
**症状**: iPhone Termius から Mac に繋がらない
**HG-3 FACTS 収集**:
- `doctor.sh` HEALTHY, Tailscale up, 鍵 fingerprint 一致, Mosh 前回成功実績あり
- `pmset -g log` が 2026-04-22 14:59 の Sleep で途切れていた
- 昨日の Mac は Maintenance Sleep/DarkWake ループの連続
- `caffeinate` LaunchAgent 未設置 (Phase 1 設計どおり、WARN のみ)
**HG-4 HYPOTHESIS**: 前セッション離脱時に手動 caffeinate を打ち忘れ、Mac が deep sleep → iPhone 不達
**HG-5 即時対応**: `nohup caffeinate -dis &` で復旧後、本 v0.3.0 で恒久対策

---

## v0.2.0 (2026-04-22) — **Phase 1 完全完了** ✅ [superseded by v0.3.0]

全 forge_ace ゲート PASS + gatekeeper HG-5 実機検証 PASS + PQG 残課題 (Termius Free Mosh) 解決。
Phase 1 MVP は production-ready。翌日 Mac sleep 問題で v0.3.0 へ継続。

### 完了した Phase 1 DoD

- [x] 独立 Git リポジトリ `~/mobile-dev-bridge/` 初期化 + GitHub `fideguch/mobile-dev-bridge` public 連携
- [x] Claude Code シンボリックリンク (`~/.claude/skills/mobile-dev-bridge`)
- [x] スキル本体 (SKILL.md / README.md / README.en.md / QUICKSTART / SECURITY / CONTRIBUTING / CHANGELOG / LICENSE)
- [x] scripts/ (install-tier1 / verify-tier1 / doctor)
- [x] references/ (setup-tier1 / security / troubleshooting)
- [x] templates/ (tmux.conf)
- [x] CI (.github/workflows/shellcheck.yml)
- [x] **forge_ace Full**: Writer → Guardian → Overseer(full) → PM-Admin(full) → Designer 全 PASS
- [x] **gatekeeper HG-5 実機検証 PASS** (2026-04-22, iPhone 15 + MacBook)
  - Mac 側 verify-tier1.sh: 5 PASS / 0 FAIL / 1 WARN (caffeinate は Phase 2)
  - iPhone → Mac 接続: ✅ SSH mode + ✅ **Mosh mode 両方成功**
  - tmux `main` auto-attach: ✅ 動作
  - Claude Code CLI: ✅ v2.1.117 起動・対話応答
- [x] **PQG condition #1 解決**: Termius Free tier で **Mosh が動く事実を実機で確認**

### 次にやること (Phase 2 以降)

- **Phase 2**: ~~caffeinate LaunchAgent 自動化~~ (v0.3.0 で完了) + Claude iOS `remote-control` 連携
- **Phase 3**: code-server (Tier 2) 対応
- **Phase 4**: Moshi webhook / Upgrade サイクル確立

---

## Termius Free + Mosh verification log (PQG condition #1) — ✅ RESOLVED

**PQG 指示**: Termius 公式から Mosh サポートが Free tier にあるか独立検証し、結果をここに記録せよ。

### 2026-04-22 独立検証 (Phase 1 前)

- 実行: `WebFetch https://termius.com/pricing`
- 結果要約: **Termius 公式 pricing ページには Free tier の Mosh サポートが明示されていない。** Starter (Free) に列挙されている機能は「SSH and SFTP, Local vault, AI-powered autocomplete, Port Forwarding」。Mosh は feature table のどの tier にも明示的には出てこない。
- 結論: **計画書 v2.1 §1-2 の「Mosh は Free tier で動く」前提は、公式 pricing ページだけでは確認できなかった**

### 2026-04-22 実機検証 (Phase 1 DoD) — ✅ 結論: Free tier で Mosh 動作する

実機環境:
- **Mac**: macOS / `fideguch.tail84e2f5.ts.net` / tailscale 1.96.5 / mosh 1.4.0 / tmux 3.6a
- **iPhone**: iOS (iPhone 15 系) / 5G / Termius Free tier (アカウント `0000fumito@gmail.com`)
- **接続**: Tailscale P2P (WireGuard) 経由、Mac と iPhone は同一 Tailscale アカウント

検証ステップと結果:
1. ✅ Termius で Host 作成 (Address: `fideguch.tail84e2f5.ts.net`, Port: 22, SSH key: Termius 生成 ed25519 `iphone-mobile`)
2. ✅ **Use SSH: ON** → 接続成功、tmux `main` auto-attach、Claude Code 起動・対話応答
3. ✅ **Use Mosh: ON** → **接続成功、コマンド実行問題なし**
4. ✅ 結論: **Termius Free tier で Mosh は使える** (2026-04-22 現在)

### 判定

**計画書 v2.1 の「Termius Free tier = Primary, Mosh 込み」前提を実機で確定。Moshi (Secondary) への移行不要。**

公式 pricing ページに明示されていないが、Free tier でも Mosh の接続ピッカーが出現し、動作確認済。Termius の pricing 表示は Pro 機能 (SFTP / Cloud sync) を際立たせる設計で、Mosh は全 tier 共通機能と推定。

### 今後のリスク

- Termius が将来 Mosh を Pro 限定に変更した場合 → Moshi Free へ即移行 (references/migration-termius.md 予定 / Phase 4)
- 当面の監視: 年 1 回 Upgrade モードで termius.com/pricing を再確認

---

## Next session starter

次セッション開始時に最初に読むべきもの:

```bash
cd ~/mobile-dev-bridge
cat HANDOFF.md                              # この文書
cat CHANGELOG.md                            # v0.1.0 で何が入ったか
cat references/setup-tier1.md               # Termius Free + Mosh 検証節
gh repo view fideguch/mobile-dev-bridge     # GitHub 側の状態
./scripts/doctor.sh                         # 自分の Mac で状態確認 (non-destructive)
```

---

## Observations / Friction Log

Phase 1 実機検証中に気づいた摩擦を記録。次 Phase の改善材料。

| 日付 | 場面 | 摩擦 | 提案 |
|------|------|------|------|
| 2026-04-22 | Step A-2 `sudo tailscale up` | `brew install tailscale` は **CLI のみ**、daemon/GUI は別途必要。`failed to connect to local Tailscale service` エラー | `install-tier1.sh` で `brew install --cask tailscale` or App Store 版を案内追加 (Phase 1.1 polish) |
| 2026-04-22 | Step A-3 `sudo systemsetup -setremotelogin on` | macOS 13+ で **Full Disk Access** 権限要求、ターミナルが権限持たず失敗 | QUICKSTART/setup-tier1 に「System Settings GUI で Sharing → Remote Login ON」を先に案内 |
| 2026-04-22 | Step 4 verify-tier1.sh L2 (mosh-server) | `head -1 \| grep -q 'MOSH CONNECT'` が flush タイミング依存で flaky (私の Bash 環境 3/3 PASS, ユーザー zsh/cmux 環境 FAIL) | **修正済 v0.1.2 commit `6788b87`**: `head -8` + 全行 grep に変更、3/3 PASS 確認 |
| 2026-04-22 | Step B-5 Termius Address 入力 | `http://` プレフィックスを含めて入力してしまい `Address resolution finished with error: unknown node or service` | QUICKSTART に「❌ http:// 不要、末尾ドット不要」の明示警告 (Phase 1.1) |
| 2026-04-22 | Step B-2 Tailscale アプリ | ユーザーが **Termius と Tailscale を混同**、Termius スクショ貼って来た | QUICKSTART 冒頭に「Tailscale と Termius は別アプリ」の説明 + アイコン描写追加 |
| 2026-04-22 | heredoc コピペ | Claude の出力に含まれるインデント付き `EOF` が heredoc 終了マーカーとして認識されず shell hang | printf 版の代替コマンド提示。Assistant 側の改善 (インデント無しブロック or `<<-'EOF'` tab-only) |
| 2026-04-22 | Tailscale client/server version mismatch warning | brew CLI `1.96.4` vs cask/App Store GUI daemon `1.96.5` で warning 出る (動作は問題なし) | README で「warning は無視可」を記載、install-tier1.sh で一元化する案 (Phase 2) |

---

## Known Issues / Postmortem Candidates

Phase 1 で実際に起きた障害の記録 (全て解決済)。

| issue | first seen | root cause | status |
|-------|-----------|-----------|--------|
| verify-tier1.sh L2 mosh-server test flaky | 2026-04-22 Phase 1 HG-5 | stdout(MOSH CONNECT)/stderr(version banner) merge の flush 順依存 | ✅ RESOLVED (commit 6788b87, v0.1.2) |
| Termius Free tier Mosh 動作未確認 | 2026-04-22 PQG review | termius.com/pricing に明示なし | ✅ RESOLVED (実機で Free tier Mosh 動作確認) |
| Tailscale brew CLI + GUI daemon 分離 | 2026-04-22 Phase 1 HG-5 | brew formula tailscale は CLI のみ、daemon は別必要 | ⚠️ DOCUMENTED (Phase 1.1 で install-tier1.sh 改善予定) |
| Mac sleep で iPhone 接続不可 | 2026-04-23 v0.2.0 運用翌日 | Phase 1 は caffeinate が手動運用 (LaunchAgent 未設置)、セッション離脱時に打ち忘れて deep sleep | ✅ RESOLVED (v0.3.0 で LaunchAgent 自動化) |

---

## Phase 2 以降の memo (先走り defer)

- Claude iOS app `remote-control` の最新実装確認 (`claude --help` で subcommand 有無を見る)
- ~~`caffeinate` LaunchAgent の plist 自動生成~~ ✅ v0.3.0 で完了
- Moshi Free tier の動作確認 (Secondary として保持)
- Tailscale MagicDNS の hostname 固定化手順
- `ssh-config-snippet.template` の追加 (Phase 2, ユーザーの `~/.ssh/config` に貼る用)
- `tests/` bats-core スモークテスト導入 (Phase 1.1 polish)
- Tailscale client/daemon バージョン skew 警告の一元化

これらは **今はやらない**。Phase 1.5 実機検証 (iPhone から Mac 再起動後の再接続) が PASS してから手を付ける。
