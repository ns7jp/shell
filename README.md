# Bash・Python・PowerShellで学ぶサーバー構築運用案件パック

未経験からサーバー構築・運用エンジニアを目指す学習者向けに、現場を想定した要件定義、設計、実装、テスト、運用手順、障害対応、証跡の残し方を1つにまとめたポートフォリオです。Linux（Bash + Python）とWindows（PowerShell 7）を、**同じ設計思想で**扱います。

## このリポジトリの位置づけ

- **学習用の副作品です。** 主作品は [ns7jp/server](https://github.com/ns7jp/server) で、本人が手元のVMで操作した記録はそちらにまとめています。
- **AI支援で作成した部分が大きいです。** スクリプト・テスト・文書の多くは、AIツール（Claude Code・OpenAI Codex）の支援で作成しました。2026-09-28 時点の main で確認できる範囲では、取り込んだプルリクエスト12件（#1〜#12）のうち9件は `claude/…`、2件は `codex`・`codex/python` のブランチからのもので、マージを除くコミット29件のうち22件は作者が `Claude` です（ほかに、作者が島田則幸の PR #12 の squash merge コミットにも `Co-authored-by: Claude` が付いています）。件数はその後のプルリクエストで増えるため、最新の値は GitHub のプルリクエスト一覧とコミット履歴で確認してください。作者が島田則幸のコミットが本人の手作業か AI ツールの出力かは、履歴からは区別できません。
- **本人による実行記録:** [検証証跡](docs/08-evidence.md)の記録は、AI支援セッションの作業用コンテナとGitHub Actionsで実行したものが中心です。本人が自分の端末で実行したと確認できる記録はありません（2026-08-28 の Git for Windows での記録は、実行者を判別できず本人確認待ちです）。Bash演習21問の本人による実施も `NOT RUN` です。
- **主作品との関係:** Ansible構成管理パック・セキュリティ強化パック・変更管理・復旧パックは、主作品の `ansible/roles/`（`nginx`・`common` など）や [変更管理](https://github.com/ns7jp/server/blob/main/docs/change-management.md) と扱うテーマが重なります。本人がVMで操作した記録は主作品側にあり、このリポジトリの同じテーマのパックは、実VMへの適用を `NOT RUN` とした教材です。

> このリポジトリは学習用です。最初は必ず隔離した検証環境で実行してください。変更を伴うスクリプトは既定でドライランになり、`--execute`（PowerShellでは `-Execute`）を付けた場合だけ処理します。

## 30秒で分かる内容

架空の依頼は3段階です。まず「小規模Webサーバーを再現可能に構築する」、次に「構築後のサーバーの日次点検と保守を、誰でも同じ品質で実施できるよう自動化する」、そして「同じことをWindowsサーバーでもできるようにする」。Linux側は変更処理をBash、結果の構造化・証跡化をPythonという分担で実装し、Windows側はPowerShell 7で**同じ順序・同じログ書式・同じ終了コード**を再現しています。

| パック | 対象 | 言語 | ドキュメント |
|---|---|---|---|
| 運用パック | 構築済みLinuxサーバーの点検・バックアップ・ログ保守 | Bash + Python | [00](docs/00-project-overview.md)〜[09](docs/09-glossary-cheatsheet.md) |
| 構築パック | LinuxへのNginx構築と受け入れ試験 | Bash + Python | [11](docs/11-build-project-overview.md)〜[14](docs/14-build-test-plan.md) |
| PowerShell演習パック | WindowsへのIIS構築と、その後の運用 | PowerShell 7 | [20](docs/20-powershell-project-overview.md)〜[27](docs/27-powershell-glossary-cheatsheet.md) |
| Ansible構成管理パック | 構築パックと同じ内容をAnsibleで再現可能に構築 | Ansible (YAML) | [30](docs/30-ansible-project-overview.md)〜[33](docs/33-ansible-test-plan.md) |
| セキュリティ強化パック | 専用ユーザー、SSH、sudo、FW、更新方針、権限表 | Bash + Ansible | [40](docs/40-security-project-overview.md)〜[43](docs/43-security-test-plan.md) |
| 変更管理・復旧パック | 変更前スナップショット、変更適用、検証ゲート、自動切戻し、復元試験 | Bash | [50](docs/50-change-project-overview.md)〜[53](docs/53-change-test-plan.md) |

| スクリプト | 目的 | 通常の変更 | 安全策 |
|---|---|---:|---|
| `provision_web_server.sh` | Nginx導入、サンプルページ配置、ファイアウォール、systemd登録 | あり | 既定はドライラン、`--execute`にroot権限必須、冪等に実行 |
| `build_verify.sh` | 構築直後にパッケージ・サービス・HTTP応答・ファイアウォールを確認 | なし | 読み取り専用 |
| `harden_server.sh` | 専用ユーザー作成、SSH鍵登録、sudoers drop-in、ufw既定拒否+許可リスト、自動更新導入 | あり | 既定はドライラン、`--execute`にroot権限必須、sudoers drop-inは配置前に`visudo -c`で構文検証 |
| `verify_hardening.sh` | 強化直後にSSH root無効化・パスワード認証無効化・sudoers構文・ufw既定拒否+許可・専用ユーザーを確認 | なし | 読み取り専用 |
| `snapshot_config.sh` | 変更前の設定状態（複数の絶対パス）をタイムスタンプ付きで保存 | あり | 既定はドライラン、チェックサム付きマニフェストを作成 |
| `change_deploy.sh` | スナップショット→変更適用→既存の受け入れ試験による検証ゲート→不合格時は自動切戻し | あり | 既定はドライラン、`--execute`にroot権限必須、削除同期はしない |
| `restore_config.sh` | 指定したスナップショットを元の絶対パスへ復元し、復元後にチェックサムで一致を確認 | あり | 既定はドライラン、`--execute`にroot権限必須、cp成功だけで完了とみなさない |
| `server_audit.sh` | OS、CPU、メモリ、ディスク、サービスを点検 | なし | 読み取り専用 |
| `backup.sh` | 指定ディレクトリを世代付きで圧縮保存 | あり | 既定はドライラン、入力検証、保存先分離 |
| `rotate_app_logs.sh` | 古いアプリログを圧縮・削除 | あり | 既定はドライラン、対象拡張子・経過日数を限定 |
| `audit_report.py` | 点検ログ・構築ログをJSON証跡へ変換 | JSON作成 | 入力形式を全行検証、原子的に出力 |
| `exercises/labctl.sh` | Bash演習21問の出題・採点・進捗記録 | 学習者の作業場のみ | root不要、使い捨てサンドボックス、答案は複製して実行 |

### PowerShell演習パックのスクリプト

| スクリプト | 目的 | 通常の変更 | 安全策 |
|---|---|---:|---|
| `Install-WebServer.ps1` | IIS導入、サンプルページ配置、ファイアウォール、サービス自動起動 | あり | 既定はドライラン、`-Execute`にWindowsと管理者権限が必須、冪等に実行 |
| `Test-WebServerBuild.ps1` | 構築直後に役割・サービス・配布ファイル・HTTP応答・FWを確認 | なし | 読み取り専用 |
| `Invoke-ServerAudit.ps1` | OS、CPU、メモリ、ディスク、サービス、イベントログを点検 | なし | 読み取り専用 |
| `New-DataBackup.ps1` | 指定ディレクトリを世代付きZIPで保存 | あり | 既定はドライラン、入力検証、作成直後にZIPを開いて確認 |
| `Invoke-LogMaintenance.ps1` | 古いアプリログを圧縮・削除 | あり | 既定はドライラン、対象を直下の`*.log`に限定 |

`audit_report.py` はログ書式（`日時 [LEVEL] メッセージ`）を全スクリプトで統一しているため、点検ログにも構築ログにも同じ1本を使い回せます。**PowerShell側も同じ書式で出力するため、Windowsのログも新しい変換スクリプトなしで同じJSON証跡になります。**

## 学べること

- 要件を「入力・処理・出力・正常条件・異常条件」に分解する方法
- `set -Eeuo pipefail`、終了コード、ログ、関数、引数解析
- Python標準ライブラリによるログ解析、JSON、単体テスト、Bashとの役割分担
- 危険なパスや未定義値を拒否するフェイルクローズ設計
- ドライラン、バックアップ世代管理、ログローテーション
- パッケージ導入・ファイアウォール・systemd登録を2回実行しても壊れない冪等設計
- 構築直後の受け入れ試験による「完成」の客観的な判定
- テスト用ディレクトリを使ったroot権限不要の自動テスト
- 障害の切り分け、復旧、エスカレーション、作業証跡
- 同じ設計思想をBashとPowerShellの両方で実装する方法（LinuxとWindowsの対応表）
- PowerShellの「動詞-名詞」「オブジェクトのパイプライン」「データだけの設定ファイル(.psd1)」
- 追加モジュールなしで動く自動テストと、Windows/Linux両方で回るCI

## 最短5分の体験

対象: Ubuntu 22.04/24.04 または同等のBash環境。WindowsではWSL2を推奨します。

```bash
git clone https://github.com/ns7jp/shell.git
cd shell
chmod +x scripts/*.sh tests/run_tests.sh
make test
./scripts/server_audit.sh --config config/audit.conf.example
mkdir -p "$HOME/lab/src" && printf 'sample\n' > "$HOME/lab/src/sample.txt"
sed -e 's|^SOURCE_DIR=.*|SOURCE_DIR='"$HOME"'/lab/src|' -e 's|^BACKUP_DIR=.*|BACKUP_DIR='"$HOME"'/lab/backups|' config/backup.conf.example > "$HOME/lab/backup.conf"
./scripts/backup.sh --config "$HOME/lab/backup.conf"
./scripts/provision_web_server.sh --config config/provision.conf.example
```

`backup.sh` の設定例（`config/backup.conf.example`）は、実サーバーを想定した `/srv/example-app/data` をバックアップ元にしています。新しい環境にはこのディレクトリが無いため、設定例をそのまま指定すると「バックアップ元を読み取れません」と表示して終了コード `2` で止まります。これは不具合ではなく、存在しない場所を黙って受け入れない設計です。上の手順では、自分が読み書きできる `$HOME/lab/src` を作り、設定例のパスを書き換えた設定ファイルで実行しています（`--execute` を付けていないため、ドライランで予定だけ表示します）。

`server_audit.sh` は警告を検出すると終了コード `1`、実行不能なエラーでは `2` を返します。結果を確認する場合は直後に `echo $?` を実行してください。`provision_web_server.sh` は上記のとおり `--execute` を付けていないため、何も変更しません。実際にサーバーを構築する手順は、専用の検証環境（VMやコンテナ）を用意したうえで[構築ハンズオン](docs/13-build-hands-on.md)に従ってください。

### PowerShell演習パックを試す

対象: PowerShell 7.0以上（`pwsh`）。自動テストはどのOSでも実行できます。

```bash
make ps-test    # 構文チェックと自動テスト（追加モジュールのインストールは不要）
```

Windowsでは、設定例をそのまま指定してドライラン（変更せず予定だけ表示）を確認できます。

```powershell
pwsh -NoProfile -File scripts\powershell\Install-WebServer.ps1 -ConfigPath config\powershell\websetup.psd1.example
```

`-Execute` を付けていないため何も変更しません。

**Windows以外で試す場合**は、設定例のパス（`C:\inetpub\wwwroot` など）がそのOSの絶対パスではないため、終了コード2で拒否されます。これは不具合ではなく、実在しない場所を黙って受け入れない設計です。次のようにパスを書き換えてから実行してください。

```bash
sed 's|C:\\inetpub\\wwwroot|'"$HOME"'/ps-lab/wwwroot|' config/powershell/websetup.psd1.example > "$HOME/websetup.psd1"
pwsh -NoProfile -File scripts/powershell/Install-WebServer.ps1 -ConfigPath "$HOME/websetup.psd1"
```

実際にIISを構築する手順は、使い捨ての検証環境を用意したうえで[PowerShellハンズオン](docs/24-powershell-hands-on.md)に従ってください。

点検ログを機械可読な証跡にする一連の流れは次のとおりです（出力先は自分が書き込める絶対パスに変更します）。

```bash
./scripts/server_audit.sh --config config/audit.conf.example --output "$PWD/audit.log"
audit_status=$?
python3 scripts/audit_report.py --input "$PWD/audit.log" --output "$PWD/audit.json"
report_status=$?
printf 'audit=%s report=%s\n' "$audit_status" "$report_status"
```

## 学習ルート

0. [Bash演習案件パック](exercises/README.md)で手を動かす（[案内](docs/15-exercise-pack-guide.md) / [暗記チートシート](docs/17-memory-cheatsheet.md)）
1. [案件概要](docs/00-project-overview.md)で依頼と完成条件をつかむ
2. [要件定義](docs/01-requirements.md)で「何を作るか」を読む
3. [基本設計](docs/02-design.md)で処理の流れと安全策を理解する
4. [環境構築](docs/03-setup.md)で検証環境を準備する
5. [ハンズオン](docs/04-hands-on.md)で1行ずつ意味を確認する
6. [テスト仕様](docs/05-test-plan.md)に沿って期待値と実結果を記録する
7. [運用・障害対応](docs/06-operations-runbook.md)で現場の報告方法を練習する
8. [面接説明ガイド](docs/07-interview-guide.md)で成果を自分の言葉にする
9. [検証証跡](docs/08-evidence.md)で実施済みと未実施を区別する
10. [用語集・チートシート](docs/09-glossary-cheatsheet.md)で5語の流れを復習する
11. [構築案件概要](docs/11-build-project-overview.md)でサーバーを新しく作る側の依頼をつかむ
12. [構築の基本設計](docs/12-build-design.md)でネットワーク構成、ポート、冪等性の考え方を理解する
13. [構築ハンズオン](docs/13-build-hands-on.md)で検証環境に実際にNginxを構築する
14. [構築テスト仕様](docs/14-build-test-plan.md)で構築の完成条件を確認する
15. [サーバー構築ポートフォリオへの発展計画](docs/10-server-build-roadmap.md)で不足範囲と次の成果物を確認する
16. [Bash演習パックの採点設計](docs/16-exercise-grading-design.md)で、採点をどう機械化したかを読む
17. [PowerShell演習案件概要](docs/20-powershell-project-overview.md)でWindows側の依頼をつかむ
18. [PowerShell演習の要件定義](docs/21-powershell-requirements.md)で作るものを読む
19. [PowerShell演習の基本設計](docs/22-powershell-design.md)でBash版との対応関係を理解する
20. [PowerShell演習の検証環境の構築](docs/23-powershell-setup.md)で自分の環境でどこまでできるか決める
21. [PowerShellハンズオン](docs/24-powershell-hands-on.md)で11の演習を手を動かして進める
22. [PowerShell演習のテスト仕様](docs/25-powershell-test-plan.md)で自動テストとNOT RUNを確認する
23. [PowerShell運用・障害対応手順](docs/26-powershell-operations-runbook.md)でWindowsの切り分けを練習する
24. [PowerShell用語集・チートシート](docs/27-powershell-glossary-cheatsheet.md)で合言葉6つと対応表を暗記する
25. [Ansible構成管理案件概要](docs/30-ansible-project-overview.md)で構成の再現性という依頼をつかむ
26. [Ansibleの基本設計](docs/31-ansible-design.md)でBash版との対応関係と冪等性の根拠を理解する
27. [Ansibleハンズオン](docs/32-ansible-hands-on.md)で構文チェックと初期VMへの適用の流れを確認する
28. [Ansibleテスト仕様](docs/33-ansible-test-plan.md)で自動テストとNOT RUNを確認する
29. [セキュリティ強化案件概要](docs/40-security-project-overview.md)で専用ユーザー・SSH・sudo・FWという依頼と権限表をつかむ
30. [セキュリティ強化の基本設計](docs/41-security-design.md)で最小権限と既定拒否の設計理由を理解する
31. [セキュリティ強化ハンズオン](docs/42-security-hands-on.md)で検証環境に実際に強化設定を適用する
32. [セキュリティ強化テスト仕様](docs/43-security-test-plan.md)で自動テストとNOT RUNを確認する
33. [変更管理・復旧案件概要](docs/50-change-project-overview.md)で変更手順・切戻し条件という依頼と`backup.sh`との違いをつかむ
34. [変更管理・復旧の基本設計](docs/51-change-design.md)で切戻し基準表と復元試験の設計理由を理解する
35. [変更管理・復旧ハンズオン](docs/52-change-hands-on.md)で検証環境に実際にスナップショット・変更・自動切戻しを試す
36. [変更管理・復旧テスト仕様](docs/53-change-test-plan.md)で自動テストとNOT RUNを確認する

## ディレクトリ構成

```text
ansible/              Ansible構成管理パック（プレイブック・ロール・在庫例）
config/               設定例（本番値や秘密情報は置かない）
config/powershell/    PowerShell用の設定例（.psd1）
docs/                 要件、設計、構築、テスト、運用、証跡
examples/             実行結果の読み方
exercises/            Bash演習21問と採点ツール（root不要）
scripts/              Bash・Pythonの実装
scripts/lib/          Bashの共通関数
scripts/powershell/   PowerShellの実装
scripts/powershell/Modules/OpsCommon/   PowerShellの共通モジュール
tests/                root不要の自動テスト
tests/powershell/     追加モジュール不要のPowerShell自動テスト
.github/workflows/    CI（Linux・Windowsの両方でPowerShellを検証）
PSScriptAnalyzerSettings.psd1  PowerShell静的解析の設定（除外理由つき）
Makefile              検証コマンドの入口
```

## 評価しやすいポイント

- **再現性:** 設定値をコードから分離し、同じ手順を別環境でも実行可能
- **安全性:** 変更系はドライランが標準で、危険な対象を入力検証で拒否
- **保守性:** 共通処理を `scripts/lib/common.sh` に集約し、証跡化は `audit_report.py` 1本を構築・運用の両方で再利用
- **検証可能性:** 成功・警告・入力エラーを終了コードで区別し自動テスト。CIはLinuxとWindowsの両方で実行
- **移植性:** 同じ設計をBashとPowerShellの両方で実装し、ログ書式を統一して証跡化スクリプトを共有
- **説明責任:** 実行日時、コマンド、期待値、結果を証跡テンプレートに記録
- **育成可能性:** 演習21問を自動採点し、「模範解答で合格・誤答で不合格」をCIで毎回検証

## 現在の検証範囲

静的検証と自己完結テスト、コンテナ内でのNginx導入までは実行できますが、実Ubuntu VMでの構築、再起動後のsystemd自動起動、実ufw導入によるポート到達性、バックアップ復元、cron連携、長期運用、性能試験は環境依存です。

PowerShell演習パックについては、Linux上のPowerShell 7で構文検証・自動テスト・ドライラン・バックアップ・ログ保守・証跡化まで実行でき、GitHub ActionsのubuntuジョブとWindowsジョブの両方で自動テストとPSScriptAnalyzerが通っています。ただし、**CIランナーはIISを実際に構築したわけではなく、Windows実機でのIIS構築、サービス自動起動、ファイアウォール到達性は未実施（`NOT RUN`）です。** Windows専用コマンドが存在しない環境では、その項目を `OK` にせず必ず警告として記録します。

未実施の項目を「実施済み」とは扱いません。詳細は[検証証跡](docs/08-evidence.md)を参照してください。

## ライセンス

[MIT License](LICENSE)
