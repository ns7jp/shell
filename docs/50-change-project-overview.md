# 50. 変更管理・復旧案件概要

## 架空案件

[11. 構築案件概要](11-build-project-overview.md)でNginx構築を、[40. セキュリティ強化案件概要](40-security-project-overview.md)で最小権限化を仕上げた後、同じ会社から続きの相談を受けた想定です。

> Webサーバーは安全な既定値で構築・強化できるようになりました。ですが、構築後に設定を変更する場面（サイト内容の更新、設定ファイルの調整）では、まだ「変更前の状態をどう残すか」「失敗したときにいつ止めて、どう元へ戻すか」が決まっていません。新人が変更作業を任されたとき、壊れたら終わりではなく、必ず元へ戻せる状態で作業できるようにしてください。

位置づけとしては、[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)の優先度2「変更・復旧」（変更手順、切戻し条件、設定バックアップ、復元試験）を、実際に動くBashスクリプトとして実装したものです。[11. 構築案件概要](11-build-project-overview.md)・[40. セキュリティ強化案件概要](40-security-project-overview.md)が作った「安全に運用へ引き渡せる状態」に対して、このパックは「そのサーバーを安全に変更し、失敗したら確実に戻せる状態」を追加します。

## 利用者と困りごと

| 利用者 | 困りごと | この案件での解決 |
|---|---|---|
| 新人担当 | 変更作業のたびに「まず何を保存すればよいか」が分からず、変更前の状態を記録し忘れる | `snapshot_config.sh`が`SNAPSHOT_TARGETS`に列挙した対象を機械的にタイムスタンプ付きで保存する。変更本体（`change_deploy.sh`）は必ず内部でこれを呼ぶため、保存し忘れる余地がない |
| リーダー | 「失敗したら止めて戻す」の基準が担当者の感覚に依存し、誰がやっても同じ判断になるか分からない | `change_deploy.sh`は既存の受け入れ試験（`build_verify.sh`等）の終了コードだけで機械的にgo/no-go判定する（[51. 変更管理・復旧の基本設計](51-change-design.md)の切戻し基準表を参照） |
| 監査担当 | 「復元した」という報告が、実際に元の状態と一致しているか確認できない | `restore_config.sh`は復元後に元のスナップショット時点のチェックサムと突き合わせ、一致しなければ警告する。「cpが成功した」だけでは完了と判定しない |
| 承認者 | 変更をいつ・誰が・どの範囲で行ってよいか基準がない | 本ドキュメントに変更ウィンドウと承認者を明記し、[51. 変更管理・復旧の基本設計](51-change-design.md)で切戻し条件（自動/人による判断）を区別する |
| 運用担当 | 既存のバックアップ（`backup.sh`）と、変更前後のスナップショットの違いが分からない | 下記「`backup.sh`との違い」に、目的・保持方針・利用場面の違いを明記する |

## スコープ

含むものは、変更前の設定状態を保存するスナップショット（`snapshot_config.sh`）、既存の受け入れ試験を検証ゲートとして使う変更適用フロー（`change_deploy.sh`）、スナップショットからの復元と復元後の差分確認（`restore_config.sh`）、切戻し基準表（自動切戻し条件と人による判断が必要な条件の区別）、変更ウィンドウと承認者の明記です。

含まないものは、実際のnginx/ufw/sshd/systemdへの本番変更適用、Gitや構成管理ツール（Ansible）と統合した変更履歴管理、複数担当者による承認ワークフロー（チケットシステム連携）、変更内容の自動レビュー（diffの意味解析）です。これらは今回のスコープ外ですが、位置づけと今後の方向性は[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)にまとめています。

**このパックは、検証環境（コンテナ、この検証セッション）の実際のnginx・ufw・sshd・systemd設定を一切変更しません。** `snapshot_config.sh`・`restore_config.sh`・`change_deploy.sh`の対象パスはすべて`config/change.conf`の変数で指定する絶対パスであり、自動テスト（`tests/run_tests.sh`）は一時ディレクトリのパスに差し替えて実行します。`config/change.conf.example`の既定値（`/etc/nginx/sites-enabled`等）は実Ubuntu VMを想定した値で、この検証環境に対して`--execute`を実行したことはありません。

### `backup.sh`との違い

既存の`scripts/backup.sh`（[00. 案件概要](00-project-overview.md)以降のパック）と、このパックの`snapshot_config.sh`は、どちらも「コピーして保存する」という点で似ていますが、目的が異なるため、`backup.sh`を流用・パラメータ化するのではなく別スクリプトとして実装しました。理由は次のとおりです。

| 観点 | `backup.sh`（既存） | `snapshot_config.sh`（本パック） |
|---|---|---|
| 対象 | `SOURCE_DIR`という単一のディレクトリ（利用者データ想定） | `SNAPSHOT_TARGETS`という複数の絶対パス（設定ファイル・設定ディレクトリの集合） |
| 保存形式 | 1つの`tar.gz`アーカイブ | 元の絶対パス構造を保ったディレクトリ（`payload/`配下にミラー）+ チェックサムの`manifest.txt` |
| 保持方針 | `RETENTION_DAYS`による世代管理・自動削除（継続的な保存が目的） | 保持期間の自動削除はしない。1回の変更に対応する1スナップショットとして扱う（変更のたびに作成・切戻しに使う） |
| 復元の主目的 | 誤って消したデータを取り戻す（`tar -xzf`で手動展開） | 変更前の状態と**チェックサムで一致することを確認したうえで**元の絶対パスへ書き戻す（`restore_config.sh`が自動で突き合わせる） |
| 呼び出し元 | 単独で定期実行（例: cron） | `change_deploy.sh`が変更のたびに自動的に呼び出す |

**両者は保持期間の考え方（継続的な世代管理 vs. 変更ごとの1回きりのロールバック用）と、復元時に要求する保証（展開できればよい vs. 元と一致することを機械的に証明する）が異なるため、無理に1本へ統合せず、共通ライブラリ（`scripts/lib/common.sh`）だけを共有する設計にしました。**この判断は[51. 変更管理・復旧の基本設計](51-change-design.md)でさらに詳しく説明します。

### 設定キー一覧

| キー | 意味 | 既定値の例 | 使うスクリプト |
|---|---|---|---|
| `SNAPSHOT_DIR` | スナップショットの保存先（絶対パス） | `/var/backups/change-snapshots` | 3本すべて |
| `SNAPSHOT_TARGETS` | 変更前後で保存・比較する対象（絶対パス、空白区切り） | `/etc/nginx/sites-enabled /etc/ufw ... /var/www/html` | `snapshot_config.sh`・`change_deploy.sh` |
| `CHANGE_TARGET` | `change_deploy.sh`が実際に上書きする単一の変更対象（絶対パス） | `/var/www/html` | `change_deploy.sh`のみ |
| `VERIFY_CMD` | 変更適用後に実行するgo/no-go判定コマンド | `bash scripts/build_verify.sh --config config/provision.conf.example` | `change_deploy.sh`のみ |

`SNAPSHOT_DIR`・`SNAPSHOT_TARGETS`は`snapshot_config.sh`の必須項目です。`CHANGE_TARGET`は`SNAPSHOT_TARGETS`に含まれていない場合、`change_deploy.sh`は終了コード2で拒否します（切戻せない変更を実行させないため）。

## 完成条件

1. 初心者がREADMEから何もこわさずドライランを体験できる。

   ```bash
   cp config/change.conf.example config/change.conf
   chmod 600 config/change.conf
   bash scripts/snapshot_config.sh --config config/change.conf --label demo
   bash scripts/change_deploy.sh --config config/change.conf --source examples
   ```

   既定は必ずドライランです。スナップショットの作成、変更対象への書き込み、切戻しのいずれも実行されず、`[DRY-RUN]`を先頭に付けて表示するだけです。

2. `--execute`を明示しない限り変更が起きない。`snapshot_config.sh`・`restore_config.sh`・`change_deploy.sh`のいずれも、`provision_web_server.sh`・`harden_server.sh`と同じメッセージ・同じ終了コード（2）でroot権限なしの`--execute`を拒否します（`restore_config.sh`・`change_deploy.sh`のみ。`snapshot_config.sh`は`backup.sh`と同じくroot権限を要求しません）。

3. `change_deploy.sh`は既存の受け入れ試験を検証ゲートとして再利用し、失敗時に自動で切戻す。

   ```bash
   sudo bash scripts/change_deploy.sh --config config/change.conf --source /path/to/new-site --execute
   ```

   検証ゲート（`VERIFY_CMD`）の終了コードに応じた挙動は[51. 変更管理・復旧の基本設計](51-change-design.md)の切戻し基準表のとおりです。

4. `restore_config.sh`は復元後にチェックサムで差分を確認し、一致しなければ警告する。「コピーが成功した」だけを完成条件にしません。

5. 実機VMでの適用など、未実施の項目は`NOT RUN`と明記する。

   | 項目 | 状態 | 備考 |
   |---|---|---|
   | 実Ubuntu VMでの`change_deploy.sh --execute`（実nginx設定・実サイトへの適用） | NOT RUN（検証環境に依存します） | [40. セキュリティ強化案件概要](40-security-project-overview.md)と同じ理由で、この検証環境には`ufw`・`sshd`が入っておらず、実システムへの変更を避けるため意図的に実行していません。 |
   | 実際の変更ウィンドウ運用（承認フロー含む）での試行 | NOT RUN | 承認ワークフローはこのパックのスコープ外です（下記「切戻し基準」参照）。 |

   一方、このセッションで**実際に**実行し確認できたのは、一時ディレクトリを対象にした「変更適用 → 検証ゲート合格 → 確定」「変更適用 → 検証ゲート失敗（終了コード2）→ 自動切戻し → チェックサム一致確認」「変更適用 → 検証ゲート警告（終了コード1）→ 自動切戻しせず変更を維持」の3系統です。詳細は[53. 変更管理・復旧テスト仕様](53-change-test-plan.md)を参照してください。

## 変更ウィンドウと承認者

| 項目 | 方針 |
|---|---|
| 変更ウィンドウ | 業務影響を最小化するため、利用者の少ない時間帯（深夜または休日メンテナンス枠）に限定する。1回の変更作業は`change_deploy.sh`のスナップショット〜検証ゲート判定までを**30分以内**に完了させることを目安とする（検証ゲートの応答が遅い場合は、時間切れ自体を「no-go」として扱い、いったん切戻す） |
| 承認者 | 変更内容（`--source`の中身）は、実施前にリーダー相当の承認者がレビューする。承認なしに本番の`CHANGE_TARGET`へ`--execute`を実行しない |
| 実施者 | 承認された変更を`change_deploy.sh`で実施する担当者は、承認者と別人であることが望ましい（実施者自身が承認も兼ねると、レビューが形骸化しやすいため） |
| 記録 | 実施者は、実行コマンド・スナップショットのパス・検証ゲートの結果・終了コードをそのままログとして残す（[08. 検証証跡](08-evidence.md)の証跡テンプレートを流用する） |

## 作業工程

`要件確認 → 設計 → 実装 → 静的検証 → テスト → ロードマップ更新`

| 工程 | 内容 |
|---|---|
| 要件確認 | 変更前の状態を必ず保存し、失敗時の切戻し基準を機械的に判定できることを要件にする |
| 設計 | `config/change.conf.example`の設定キーと、切戻し基準表（自動/人による判断）を決める |
| 実装 | `scripts/snapshot_config.sh`・`scripts/restore_config.sh`・`scripts/change_deploy.sh`を作成する |
| 静的検証 | `bash -n`を実行する（`make syntax`） |
| テスト | `tests/run_tests.sh`に本パックのテストを追加する |
| ロードマップ更新 | [10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)の到達状況を見直す |

本番作業はこの学習パックの範囲外です。検証環境で成功しても、本番承認を省略できるわけではありません。
