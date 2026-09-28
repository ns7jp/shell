# 53. 変更管理・復旧テスト仕様

## テスト方針

このドキュメントは、[51. 変更管理・復旧の基本設計](51-change-design.md)で説明した`snapshot_config.sh`（スナップショット）・`restore_config.sh`（復元）・`change_deploy.sh`（変更適用フロー）を対象にしたテスト仕様です。[14. 構築テスト仕様](14-build-test-plan.md)がB-番号、[43. セキュリティ強化テスト仕様](43-security-test-plan.md)がH-番号を使うのに対し、このドキュメントはC-番号を使います。

自動テストは一時ディレクトリだけを使い、root権限も実際のnginx・ufw・sshd・systemd設定も必要としません。**このパックの自動テストは、実システムの`/etc`配下やWebサーバーの実ファイルを一切変更しません。** `SNAPSHOT_DIR`・`SNAPSHOT_TARGETS`・`CHANGE_TARGET`はすべて一時ディレクトリ配下のパスに差し替えてテストします。検証ゲート（`VERIFY_CMD`）も、実際の`build_verify.sh`ではなく`true`・`exit 1`・`exit 2`という固定終了コードのスタブコマンドに差し替え、go/no-go判定ロジック自体を検証します。未実施の項目は誇張せず、`NOT RUN`と明記します。

終了コードの意味は他パックと共通です（`scripts/lib/common.sh`の定義）。

| 終了コード | 定数名 | 意味 |
|---:|---|---|
| 0 | `EXIT_OK` | 正常終了、警告なし |
| 1 | `EXIT_WARNING` | 完了したが警告あり（`change_deploy.sh`では「検証ゲート警告、自動切戻しなし」を含む） |
| 2 | `EXIT_ERROR` | 入力や状態が不正なため中断（フェイルクローズ）。`change_deploy.sh`では「検証ゲート不合格、自動切戻し実施」もこれに含む |

## テストケース

| ID | 対象 | 条件 | 期待結果 | 種別 |
|---|---|---|---|---|
| C-01 | snapshot_config | 正常な設定、ドライラン（`--execute`なし） | 終了0、出力に`[DRY-RUN]`を含む | 自動 |
| C-02 | snapshot_config | ドライラン | `SNAPSHOT_DIR`配下に何も作成されない | 自動 |
| C-03 | snapshot_config | 正常な設定、`--execute` | 終了0、`payload/`配下に対象ファイルのコピーと`manifest.txt`が作成される | 自動 |
| C-04 | snapshot_config | `SNAPSHOT_DIR`未設定 | 終了2、「SNAPSHOT_DIR は必須」を含む | 自動 |
| C-05 | snapshot_config | `SNAPSHOT_DIR=/etc`（危険なパス） | 終了2、「重要なシステムディレクトリ」を含む | 自動 |
| C-06 | restore_config | スナップショット後にファイルを書き換え、`--execute`で復元 | 復元後の内容が書き換え前（スナップショット時点）と一致する | 自動 |
| C-07 | restore_config | 復元後の自己検証 | ログに「スナップショット時点とすべて一致しました」を含む（チェックサム比較） | 自動 |
| C-08 | restore_config | root権限なしで`--execute` | 終了2、「root権限が必要です」を含む（非rootで実行した場合のみ実行するテスト） | 自動 |
| C-09 | change_deploy | `VERIFY_CMD="true"`、`--execute` | 終了0、`CHANGE_TARGET`の内容が`--source`の内容に置き換わる | 自動 |
| C-10 | change_deploy | `VERIFY_CMD="exit 1"`（警告）、`--execute` | 終了1、変更は維持されたまま（自動切戻しされない） | 自動 |
| C-11 | change_deploy | `VERIFY_CMD="exit 2"`（不合格）、`--execute` | 終了2、「自動的にスナップショットへ切戻します」を含み、`CHANGE_TARGET`の内容が変更前に戻る | 自動 |
| C-12 | change_deploy | `CHANGE_TARGET`が`SNAPSHOT_TARGETS`に含まれない | 終了2、「SNAPSHOT_TARGETS に CHANGE_TARGET を含めてください」を含む | 自動 |
| C-13 | change_deploy | ドライラン（`--execute`なし） | 終了0、`CHANGE_TARGET`は変更されず、検証ゲートも実行されない | 自動 |
| C-14 | change_deploy | root権限なしで`--execute` | 終了2、「root権限が必要です」を含む（非rootで実行した場合のみ実行するテスト） | 自動 |
| C-15 | change_deploy | 実際の`build_verify.sh`をVERIFY_CMDに指定し、実Ubuntu VM上のNginxに対して適用 | 実際のHTTP応答・サービス状態を反映したgo/no-go判定ができる | NOT RUN |
| C-16 | change_deploy / restore_config | 実Ubuntu VMでの`--execute`実行と、実ファイル（nginx設定・サイト内容）の変更前後比較 | 実環境でも一時ディレクトリのテストと同じ挙動になる | NOT RUN |
| C-17 | snapshot_config / change_deploy | 同じ設定で変更適用を2回実行し、2回目のスナップショットが1回目と別ディレクトリに作られること | タイムスタンプにより毎回別のスナップショットが作成され、上書きされない | 手動 |
| C-18 | snapshot_config | `SNAPSHOT_DIR=<B>/app/snaps` に対し、`SNAPSHOT_TARGETS` を `<B>/app`・`<B>//app`・`<B>/./app`・`<B>/app/` のいずれかで指定（重なり） | 書き方によらず終了2、「SNAPSHOT_DIR とSNAPSHOT_TARGETSが重なっています」を含む（2026-09-28追加。[08. 検証証跡](08-evidence.md)を参照） | 自動 |

C-01からC-14とC-18は自動テストとして実施済みです。C-08・C-14は実行環境がrootのときはスキップされ、その旨をテスト結果に残します（`tests/run_tests.sh`内で`id -u`が0でない場合のみ実行、B-06・H-09と同じ方式）。C-15・C-16は実行環境（実VM）が無いため`NOT RUN`です。C-17は自動化しておらず、実行者が結果を読んで判断する「手動」です。

## 実際に確認した結果（この検証環境）

> **実行者:** この節の結果は、2026-09-09 にこのパックを追加した AI 支援セッション（Claude Code、コミット `b364c24`）が、作業用のコンテナで実行したものです。本人が自分の端末や実VMで実行した記録ではありません。[08. 検証証跡](08-evidence.md)の台帳では「記録なし」として扱っています。

この検証環境（コンテナ、root権限で動作、`nginx`・`ufw`・`sshd`は未導入）で、実際に実行して確認できた事実だけを記します。

| 確認内容 | 結果 |
|---|---|
| `bash -n scripts/snapshot_config.sh` / `scripts/restore_config.sh` / `scripts/change_deploy.sh` | 構文エラーなし（確認済み、`make syntax`に含まれる）。 |
| スナップショットのドライラン | `[DRY-RUN]`表示のみで、`SNAPSHOT_DIR`配下に何も作成されません（確認済み）。 |
| スナップショットの実行 | 一時ディレクトリを対象に`--execute`を実行し、`payload/`配下に対象ファイルのコピーと`manifest.txt`（sha256）が作成されることを確認しました。 |
| 復元と復元後のチェックサム比較 | スナップショット後に対象ファイルを書き換え、`restore_config.sh --execute`で復元した結果、内容が書き換え前と一致すること、および復元後のチェックサム再計算がスナップショット時点のマニフェストと一致することを、実際にファイル内容を比較して確認しました（`cp`の成功コードだけに頼らない確認です）。 |
| `change_deploy.sh`の合格パス | `VERIFY_CMD="true"`で`--execute`を実行し、`CHANGE_TARGET`の内容が`--source`の内容に置き換わり、終了コード0になることを確認しました。 |
| `change_deploy.sh`の警告パス（自動切戻ししない） | `VERIFY_CMD="exit 1"`で`--execute`を実行し、終了コード1になり、`CHANGE_TARGET`の内容が変更後のまま維持される（自動切戻しされない）ことを確認しました。 |
| `change_deploy.sh`の不合格パス（自動切戻しする） | `VERIFY_CMD="exit 2"`で`--execute`を実行し、「自動的にスナップショットへ切戻します」というログとともに`restore_config.sh`が自動的に呼び出され、`CHANGE_TARGET`の内容が変更前の内容に戻り、復元後のチェックサムがスナップショット時点と一致することを確認しました。終了コードは2でした。 |
| 危険な設定・不整合な設定の拒否 | `SNAPSHOT_DIR`未設定、`SNAPSHOT_DIR=/etc`、`CHANGE_TARGET`が`SNAPSHOT_TARGETS`に含まれない場合は、いずれも終了コード2で拒否されます（確認済み）。 |
| root権限のない`--execute` | この検証セッションは実際にはrootで動いているため、`tests/run_tests.sh`実行時はこのアサーション自体がスキップされ、「restore root requirement check skipped (running as root)」として記録されました。ロジック自体は`harden_server.sh`のH-09・`provision_web_server.sh`のB-06と同じ実装で、コードレビューで確認できます。 |
| `bash tests/run_tests.sh`（本パックのテストを含む全体） | 68件中68件が`ok`で、テスト全体は成功（終了コード0）しました（確認済み）。内訳は既存パックのテストに加え、C-01からC-14相当のアサーション（本パック22件程度）を含みます。 |
| 実Ubuntu VMへの適用、実nginx設定への変更・切戻し | 実行していません（NOT RUN）。理由は上表のとおりです。 |

## 実行方法

```bash
make syntax
make test
make lint      # 要shellcheck（この検証環境では未導入のため未実施）
```

- `make syntax`は`bash -n`で`snapshot_config.sh`・`restore_config.sh`・`change_deploy.sh`を含む全スクリプトの構文を確認します。
- `make test`は`tests/run_tests.sh`を実行し、C-01からC-14を含む全アサーションを1本のスクリプトで流します。
- `make lint`は`shellcheck scripts/*.sh scripts/lib/*.sh tests/*.sh`を実行し、本パックの3本もチェック対象に含まれます。この検証環境には`shellcheck`が導入されておらず、`make lint`自体は実行できませんでした（`command -v shellcheck`が失敗し、要インストールの案内を出して終了コード2で止まります。**NOT RUN**）。

本体の使い方は次のとおりです。詳しい手順は[52. 変更管理・復旧ハンズオン](52-change-hands-on.md)を参照してください。

```bash
bash scripts/snapshot_config.sh --config config/change.conf.example --label demo --execute
bash scripts/change_deploy.sh --config config/change.conf.example --source /path/to/new-content --execute
bash scripts/restore_config.sh --config config/change.conf.example --snapshot /path/to/snapshot --execute
```

## 証跡テンプレート

```text
テストID:
日時・タイムゾーン:
実行者:
環境(OS/Bash/commit):
実行コマンド:
期待結果:
実結果:
終了コード:
判定(PASS/FAIL/NOT RUN):
ログまたはスクリーンショット:
備考・課題ID:
```

FAILを隠してPASSに変更しないことが大切です。修正後は新しい実行記録を追加し、どのコミットで直ったかを残します。C-15・C-16のように実行環境が無くて確認できない項目は、判定欄に`NOT RUN`とだけ書き、備考に「検証環境に依存します」など理由を添えてください。C-17は判定欄に`手動`と書き、実行者名と目視確認した内容を備考に残してください。実施済みの記録は[08. 検証証跡](08-evidence.md)にまとめます。
