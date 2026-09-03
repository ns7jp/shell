# Bash・Python・PowerShellで学ぶサーバー構築運用案件パック

未経験からサーバー構築・運用エンジニアを目指す学習者向けに、現場を想定した要件定義、設計、実装、テスト、運用手順、障害対応、証跡の残し方を1つにまとめたポートフォリオです。Linux（Bash + Python）とWindows（PowerShell 7）を、**同じ設計思想で**扱います。

> このリポジトリは学習用です。最初は必ず隔離した検証環境で実行してください。変更を伴うスクリプトは既定でドライランになり、`--execute`（PowerShellでは `-Execute`）を付けた場合だけ処理します。

## 30秒で分かる内容

架空の依頼は3段階です。まず「小規模Webサーバーを再現可能に構築する」、次に「構築後のサーバーの日次点検と保守を、誰でも同じ品質で実施できるよう自動化する」、そして「同じことをWindowsサーバーでもできるようにする」。Linux側は変更処理をBash、結果の構造化・証跡化をPythonという分担で実装し、Windows側はPowerShell 7で**同じ順序・同じログ書式・同じ終了コード**を再現しています。

| パック | 対象 | 言語 | ドキュメント |
|---|---|---|---|
| 運用パック | 構築済みLinuxサーバーの点検・バックアップ・ログ保守 | Bash + Python | [00](docs/00-project-overview.md)〜[09](docs/09-glossary-cheatsheet.md) |
| 構築パック | LinuxへのNginx構築と受け入れ試験 | Bash + Python | [11](docs/11-build-project-overview.md)〜[14](docs/14-build-test-plan.md) |
| PowerShell演習パック | WindowsへのIIS構築と、その後の運用 | PowerShell 7 | [20](docs/20-powershell-project-overview.md)〜[27](docs/27-powershell-glossary-cheatsheet.md) |

| スクリプト | 目的 | 通常の変更 | 安全策 |
|---|---|---:|---|
| `provision_web_server.sh` | Nginx導入、サンプルページ配置、ファイアウォール、systemd登録 | あり | 既定はドライラン、`--execute`にroot権限必須、冪等に実行 |
| `build_verify.sh` | 構築直後にパッケージ・サービス・HTTP応答・ファイアウォールを確認 | なし | 読み取り専用 |
| `server_audit.sh` | OS、CPU、メモリ、ディスク、サービスを点検 | なし | 読み取り専用 |
| `backup.sh` | 指定ディレクトリを世代付きで圧縮保存 | あり | 既定はドライラン、入力検証、保存先分離 |
| `rotate_app_logs.sh` | 古いアプリログを圧縮・削除 | あり | 既定はドライラン、対象拡張子・経過日数を限定 |
| `audit_report.py` | 点検ログ・構築ログをJSON証跡へ変換 | JSON作成 | 入力形式を全行検証、原子的に出力 |

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
./scripts/backup.sh --config config/backup.conf.example
./scripts/provision_web_server.sh --config config/provision.conf.example
```

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
16. [PowerShell演習案件概要](docs/20-powershell-project-overview.md)でWindows側の依頼をつかむ
17. [PowerShell演習の要件定義](docs/21-powershell-requirements.md)で作るものを読む
18. [PowerShell演習の基本設計](docs/22-powershell-design.md)でBash版との対応関係を理解する
19. [PowerShell演習の検証環境の構築](docs/23-powershell-setup.md)で自分の環境でどこまでできるか決める
20. [PowerShellハンズオン](docs/24-powershell-hands-on.md)で11の演習を手を動かして進める
21. [PowerShell演習のテスト仕様](docs/25-powershell-test-plan.md)で自動テストとNOT RUNを確認する
22. [PowerShell運用・障害対応手順](docs/26-powershell-operations-runbook.md)でWindowsの切り分けを練習する
23. [PowerShell用語集・チートシート](docs/27-powershell-glossary-cheatsheet.md)で合言葉6つと対応表を暗記する

## ディレクトリ構成

```text
config/               設定例（本番値や秘密情報は置かない）
config/powershell/    PowerShell用の設定例（.psd1）
docs/                 要件、設計、構築、テスト、運用、証跡
examples/             実行結果の読み方
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

## 現在の検証範囲

静的検証と自己完結テスト、コンテナ内でのNginx導入までは実行できますが、実Ubuntu VMでの構築、再起動後のsystemd自動起動、実ufw導入によるポート到達性、バックアップ復元、cron連携、長期運用、性能試験は環境依存です。

PowerShell演習パックについては、Linux上のPowerShell 7で構文検証・自動テスト・ドライラン・バックアップ・ログ保守・証跡化まで実行でき、GitHub ActionsのubuntuジョブとWindowsジョブの両方で自動テストとPSScriptAnalyzerが通っています。ただし、**CIランナーはIISを実際に構築したわけではなく、Windows実機でのIIS構築、サービス自動起動、ファイアウォール到達性は未実施（`NOT RUN`）です。** Windows専用コマンドが存在しない環境では、その項目を `OK` にせず必ず警告として記録します。

未実施の項目を「実施済み」とは扱いません。詳細は[検証証跡](docs/08-evidence.md)を参照してください。

## ライセンス

[MIT License](LICENSE)
