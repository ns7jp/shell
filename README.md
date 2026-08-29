# Python・シェルで学ぶLinuxサーバー構築運用案件パック

未経験からサーバー構築・運用エンジニアを目指す学習者向けに、現場を想定した要件定義、設計、実装、テスト、運用手順、障害対応、証跡の残し方を1つにまとめたポートフォリオです。

> このリポジトリは学習用です。最初は必ず隔離したLinux検証環境で実行してください。変更を伴うスクリプトは既定でドライランになり、`--execute` を付けた場合だけ処理します。

## 30秒で分かる内容

架空の依頼は2段階です。まず「小規模Webサーバーを再現可能に構築する」、次に「構築後のサーバーの日次点検と保守を、誰でも同じ品質で実施できるよう自動化する」。どちらも変更処理はBash、結果の構造化・証跡化はPythonという分担で実装しています。

| スクリプト | 目的 | 通常の変更 | 安全策 |
|---|---|---:|---|
| `provision_web_server.sh` | Nginx導入、サンプルページ配置、ファイアウォール、systemd登録 | あり | 既定はドライラン、`--execute`にroot権限必須、冪等に実行 |
| `build_verify.sh` | 構築直後にパッケージ・サービス・HTTP応答・ファイアウォールを確認 | なし | 読み取り専用 |
| `server_audit.sh` | OS、CPU、メモリ、ディスク、サービスを点検 | なし | 読み取り専用 |
| `backup.sh` | 指定ディレクトリを世代付きで圧縮保存 | あり | 既定はドライラン、入力検証、保存先分離 |
| `rotate_app_logs.sh` | 古いアプリログを圧縮・削除 | あり | 既定はドライラン、対象拡張子・経過日数を限定 |
| `audit_report.py` | 点検ログ・構築ログをJSON証跡へ変換 | JSON作成 | 入力形式を全行検証、原子的に出力 |

`audit_report.py` はログ書式（`日時 [LEVEL] メッセージ`）を全スクリプトで統一しているため、点検ログにも構築ログにも同じ1本を使い回せます。

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

## ディレクトリ構成

```text
config/               設定例（本番値や秘密情報は置かない）
docs/                 要件、設計、構築、テスト、運用、証跡
examples/             実行結果の読み方
scripts/              実装
scripts/lib/          共通関数
tests/                root不要の自動テスト
.github/workflows/    CI
Makefile              検証コマンドの入口
```

## 評価しやすいポイント

- **再現性:** 設定値をコードから分離し、同じ手順を別環境でも実行可能
- **安全性:** 変更系はドライランが標準で、危険な対象を入力検証で拒否
- **保守性:** 共通処理を `scripts/lib/common.sh` に集約し、証跡化は `audit_report.py` 1本を構築・運用の両方で再利用
- **検証可能性:** 成功・警告・入力エラーを終了コードで区別し自動テスト
- **説明責任:** 実行日時、コマンド、期待値、結果を証跡テンプレートに記録

## 現在の検証範囲

静的検証と自己完結テスト、コンテナ内でのNginx導入までは実行できますが、実Ubuntu VMでの構築、再起動後のsystemd自動起動、実ufw導入によるポート到達性、バックアップ復元、cron連携、長期運用、性能試験は環境依存です。未実施の項目を「実施済み」とは扱いません。詳細は[検証証跡](docs/08-evidence.md)を参照してください。

## ライセンス

[MIT License](LICENSE)
