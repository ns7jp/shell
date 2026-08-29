# 11. 構築案件概要

## 架空案件

[00. 案件概要](00-project-overview.md)で整備した点検・バックアップの運用パックが一区切りついた後、同じ会社から追加の相談を受けた想定です。

> 点検・バックアップの仕組みは整いました。ですが、そもそも「サーバーを新しく作る工程」を学べていません。新人でも安全に小規模なWebサーバーを構築でき、完成したことを客観的な試験で確認できるようにしてください。

既存の運用パックは「点検対象のサーバーがすでにある」ことを前提にしていました。今回はそのサーバーを新しく作る工程を扱います。位置づけとしては、[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)にある「Phase 1: 手作業で仕組みを理解する」を、実際に動くスクリプトとして実装したものです。まだ自動化（Ansible等）や実機VMでの通し確認までは進んでいないため、その先の計画は10番のドキュメントを参照してください。

## 利用者と困りごと

| 利用者 | 困りごと | この案件での解決 |
|---|---|---|
| 新人担当 | 構築手順に自信がなく、何をどう変えるか不安 | `provision_web_server.sh` は既定がドライラン（変更せず予定だけ表示すること）で、変更には `--execute` を明示する必要がある |
| リーダー | 構築作業のやり方が特定の人しか分からない（属人化） | 手順を設定ファイルとスクリプトに落とし込み、誰が実行しても同じ検証順序・同じ判定になる |
| 監査担当 | 何をもって「構築完了」とするか基準がない | `build_verify.sh` がパッケージ導入・サービス稼働・配布ファイル・HTTP応答・ファイアウォールを終了コードで判定する |
| 運用担当 | 構築したサーバーを、既存の点検・バックアップにそのまま引き継ぎたい | `build_verify.sh` のログを既存の `audit_report.py` でJSON証跡化でき、既存の運用パックと同じログ書式を使う |

## スコープ

含むものは、nginx（Webサーバーソフトの一つ）の導入、静的サンプルページの配置、ufw（Ubuntuの簡易ファイアウォール管理ツール）によるポート許可、systemd（サービスの起動・自動起動を管理する仕組み）へのサービス登録、構築直後の受け入れ試験（`build_verify.sh`）、証跡化（既存の`audit_report.py`の再利用）です。

含まないものは、Ansible等の構成管理、クラウドやIaC（Infrastructure as Code、構成をコードで再現できるように管理する手法）、データベース、負荷分散、実際のインターネット公開、TLS証明書です。これらは今回のスコープ外ですが、位置づけと今後の方向性は[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)にまとめています。

### 設定キー一覧

構築（`provision_web_server.sh`）と受け入れ試験（`build_verify.sh`）は、同じ設定ファイル（`config/provision.conf.example`）を共有します。

| キー | 意味 | 既定値の例 | 使うスクリプト |
|---|---|---|---|
| `PACKAGE_NAME` | 導入・確認するパッケージ名 | `nginx` | 両方 |
| `SERVICE_NAME` | 起動・稼働確認するサービス名 | `nginx` | 両方 |
| `WEB_ROOT` | 配布ファイルを置く絶対パス | `/var/www/html` | 両方 |
| `SITE_TITLE` | サンプルページのタイトル | `Sample Portfolio Web Server` | `provision_web_server.sh` のみ |
| `ALLOWED_TCP_PORTS` | ufwで許可するTCPポート（空白区切り） | `22 80` | `provision_web_server.sh` のみ |
| `HTTP_PORT` | HTTP応答を確認するポート | `80` | 両方 |
| `HEALTHCHECK_PATH` | ヘルスチェック（サービスが正常か確認するためのURLパス） | `/` | `build_verify.sh` のみ |

`PACKAGE_NAME`・`SERVICE_NAME`・`WEB_ROOT`・`SITE_TITLE` は必須項目です。書き忘れると、どちらのスクリプトも終了コード2で拒否します。`WEB_ROOT` には `/etc` のような重要なシステムディレクトリそのものを指定できず、`HTTP_PORT` は1〜65535の整数以外を指定できません。いずれも同じ理由（安全側で止める、フェイルクローズ）で終了コード2になります。

## 完成条件

1. 初心者がREADMEから何もこわさずドライランを体験できる。

   ```bash
   bash scripts/provision_web_server.sh --config config/provision.conf.example
   ```

   既定は必ずドライランです。実際に変更するコマンド（`apt-get install` や `install -D` など）は実行されず、`[DRY-RUN]` を先頭に付けて表示するだけです。

2. `--execute` を明示しない限り変更が起きない。

   ```bash
   # 何も変更しない（既定）
   bash scripts/provision_web_server.sh --config config/provision.conf.example

   # 実際に変更する（root権限が必要）
   sudo bash scripts/provision_web_server.sh --config config/provision.conf.example --execute
   ```

   `--execute` を付けたのにroot権限がない場合は、「`--execute にはroot権限が必要です（sudoで実行してください）`」というメッセージとともに終了コード2で拒否します。

3. 構築直後に `build_verify.sh` で複数項目を客観的に確認できる。

   ```bash
   bash scripts/build_verify.sh --config config/provision.conf.example --output build-verify.log
   ```

   確認する項目と、確認できなかった場合のメッセージは次のとおりです。すべてOKなら終了コード0、1つでもWARNがあれば終了コード1になります。

   | 確認項目 | 確認できない場合のメッセージ |
   |---|---|
   | パッケージ導入（`dpkg -s`） | パッケージ未導入 |
   | サービス稼働（`systemctl is-active` または `pgrep`） | サービス停止または確認不能 |
   | 配布ファイル（`WEB_ROOT/index.html`） | 配布ファイルが見つかりません |
   | HTTP応答（`curl` でヘルスチェック） | HTTP応答を確認できません |
   | ファイアウォール許可（`ufw status`） | ufwが見つからない、またはファイアウォール許可を確認できません |

4. 構築ログを既存の `audit_report.py` でJSON証跡化できる。

   `provision_web_server.sh` と `build_verify.sh` のログは、既存の点検スクリプトと同じ書式（`日時 [LEVEL] メッセージ`）で出力するため、新しいPythonスクリプトを作らず、既存の `audit_report.py` をそのまま再利用できます。

   ```bash
   python3 scripts/audit_report.py --input build-verify.log --output build-verify.json
   ```

   次は検証環境（コンテナ）でnginxを手動起動した状態で `build_verify.sh` を実行し、そのログを実際に `audit_report.py` でJSON化した例です（パスは既定値の `/var/www/html` に読み替えています）。パッケージ導入・サービス稼働・配布ファイル・HTTP応答の4項目はOKになり、ufw未導入の1件だけWARNとして残っています。

   ```text
   2026-08-29T23:48:23+0000 [INFO] 構築後の受け入れ試験を開始します
   2026-08-29T23:48:23+0000 [INFO] 対象パッケージ: nginx / サービス名: nginx / ポート: 80
   2026-08-29T23:48:23+0000 [OK] パッケージ導入済み: nginx
   2026-08-29T23:48:23+0000 [OK] サービス稼働中: nginx
   2026-08-29T23:48:23+0000 [OK] 配布ファイルを確認しました: /var/www/html/index.html
   2026-08-29T23:48:23+0000 [OK] HTTP応答を確認しました: 80/ -> 200
   2026-08-29T23:48:23+0000 [WARN] ufw が見つからないためファイアウォール設定を確認できません
   2026-08-29T23:48:23+0000 [WARN] 受け入れ試験完了: 警告 1 件
   ```

   ```json
   {
     "schema_version": 1,
     "source": "build-verify.log",
     "result": "WARN",
     "counts": {
       "INFO": 2,
       "OK": 4,
       "WARN": 2,
       "ERROR": 0
     },
     "entries": [
       { "timestamp": "2026-08-29T23:48:23+0000", "level": "INFO", "message": "構築後の受け入れ試験を開始します" },
       { "timestamp": "2026-08-29T23:48:23+0000", "level": "INFO", "message": "対象パッケージ: nginx / サービス名: nginx / ポート: 80" },
       { "timestamp": "2026-08-29T23:48:23+0000", "level": "OK", "message": "パッケージ導入済み: nginx" },
       { "timestamp": "2026-08-29T23:48:23+0000", "level": "OK", "message": "サービス稼働中: nginx" },
       { "timestamp": "2026-08-29T23:48:23+0000", "level": "OK", "message": "配布ファイルを確認しました: /var/www/html/index.html" },
       { "timestamp": "2026-08-29T23:48:23+0000", "level": "OK", "message": "HTTP応答を確認しました: 80/ -> 200" },
       { "timestamp": "2026-08-29T23:48:23+0000", "level": "WARN", "message": "ufw が見つからないためファイアウォール設定を確認できません" },
       { "timestamp": "2026-08-29T23:48:23+0000", "level": "WARN", "message": "受け入れ試験完了: 警告 1 件" }
     ]
   }
   ```

   注意点として、`provision_web_server.sh` のドライラン表示（`[DRY-RUN] コマンド`の行）は日時と`[LEVEL]`を伴わない生の表示のため、この形のままでは`audit_report.py`の行形式と一致しません。証跡化は、`build_verify.sh`の出力のように、すべての行が`log`関数（`日時 [LEVEL] メッセージ`）経由で出力されたログに対して行います。

5. systemdの自動起動やufwの実環境確認など、未実施の項目は `NOT RUN` と明記する。

   | 項目 | 状態 | 備考 |
   |---|---|---|
   | systemdによる自動起動（`systemctl enable --now`） | NOT RUN（検証環境に依存します） | 今回の検証環境（コンテナ）はsystemdが動いていないため、この確認は失敗しWARN（終了コード1）になります。実際のUbuntu VMではsystemdが動くため成功する想定です。 |
   | ufwによるポート許可の実環境確認 | NOT RUN（検証環境に依存します） | 今回の検証環境にはufwが入っていないため、ファイアウォール設定はWARN（終了コード1）でスキップされます。実際のUbuntu VMではufwを導入して確認する想定です。 |

## 作業工程

`要件確認 → 設計 → 実装 → 静的検証 → テスト → 検証環境で構築 → 受け入れ試験 → 証跡 → ロードマップ更新`

| 工程 | 内容 |
|---|---|
| 要件確認 | 新人でも安全に構築でき、完成を客観的に確認できることを要件にする |
| 設計 | `config/provision.conf.example` の設定キーと、検証順序を決める |
| 実装 | `scripts/provision_web_server.sh`（構築）と `scripts/build_verify.sh`（受け入れ試験）を作成する |
| 静的検証 | 引数、必須設定、危険なパス・ポートの拒否条件をコードで確認する |
| テスト | `tests/run_tests.sh` の「構築(provision_web_server.sh)のテスト」「受け入れ試験(build_verify.sh)のテスト」で自動テストする |
| 検証環境で構築 | コンテナ等の検証環境で `--execute` を実行する |
| 受け入れ試験 | `build_verify.sh` で構築直後の状態を確認する |
| 証跡 | `audit_report.py` でログをJSON証跡化する |
| ロードマップ更新 | [10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)の到達状況を見直す |

本番作業はこの学習パックの範囲外です。検証環境で成功しても、本番承認を省略できるわけではありません。
