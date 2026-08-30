# 14. 構築テスト仕様

## テスト方針

このドキュメントは、[12. 構築の基本設計](12-build-design.md)で説明した `provision_web_server.sh`（構築）と `build_verify.sh`（受け入れ試験、構築直後に完成条件を確認する試験）を対象にしたテスト仕様です。[05. テスト仕様](05-test-plan.md)がT-番号で運用パック（点検・バックアップ）を扱うのに対し、このドキュメントはB-番号で構築パックを扱います。

自動テストは一時ディレクトリだけを使い、root権限も実際のサーバー（実VMやufw・systemd）も必要としません。そのため、ufwやsystemdが無い検証環境（コンテナなど）でも実行できます。実環境（実際のUbuntu VMなど）でしか確認できない項目は別に記録し、自動テストが成功したことだけをもって本番動作を保証しません。未実施の項目は誇張せず、`NOT RUN` と明記します。

終了コードの意味は運用パックと共通です（`scripts/lib/common.sh` の定義）。

| 終了コード | 定数名 | 意味 |
|---:|---|---|
| 0 | `EXIT_OK` | 正常終了、警告なし |
| 1 | `EXIT_WARNING` | 完了したが警告あり（フェイルクローズではなく、確認できなかっただけの項目） |
| 2 | `EXIT_ERROR` | 入力や権限が不正なため処理を中断（フェイルクローズ、安全側で停止すること） |

## テストケース

| ID | 対象 | 条件 | 期待結果 | 種別 |
|---|---|---|---|---|
| B-01 | provision | 正常な設定、ドライラン（`--execute`なし） | 終了0または1（ufwの有無に依存）、出力に`[DRY-RUN]`を含む | 自動 |
| B-02 | provision | 正常な設定、ドライラン | `WEB_ROOT/index.html` が作成されない | 自動 |
| B-03 | provision | `HTTP_PORT=70000`（範囲外） | 終了2、「1 から 65535 の範囲」を含む | 自動 |
| B-04 | provision | `PACKAGE_NAME` 未設定 | 終了2、「PACKAGE_NAME は必須」を含む | 自動 |
| B-05 | provision | `WEB_ROOT=/etc`（危険なパス） | 終了2、「重要なシステムディレクトリ」を含む | 自動 |
| B-06 | provision | root権限なしで `--execute` | 終了2、「root権限が必要です」を含む（非rootで実行した場合のみ実行するテスト） | 自動 |
| B-07 | build_verify | 不正な設定（`HTTP_PORT=70000`など） | 終了2 | 自動 |
| B-08 | build_verify | 未構築のサーバー相当の設定（存在しないパッケージ・サービス・`WEB_ROOT`） | 終了1、「パッケージ未導入」「配布ファイルが見つかりません」などの警告を複数含む | 自動 |
| B-09 | provision | 実際のUbuntu VMでの `--execute` 実行 | nginx導入からサンプルページ配置まで成功する | NOT RUN |
| B-10 | provision | VM再起動後のsystemd自動起動確認 | 再起動後もサービス稼働とHTTP応答を確認できる | NOT RUN |
| B-11 | provision | 実際にufwを有効化した後のポート到達性確認 | 許可したポート（22/tcp・80/tcp）だけに到達し、それ以外は拒否される | NOT RUN |
| B-12 | provision | 同じ設定で2回実行し、2回目の差分を目視確認 | 2回目の実行で意図しない変更が出ない（冪等性） | 手動 |
| B-13 | build_verify | 構築したサーバーに対して既存の `server_audit.sh` / `backup.sh` を実行する引き継ぎ確認 | 既存の点検・バックアップスクリプトが構築済みサーバーに対しても正常に動作する | 手動 |

B-01からB-08は `tests/run_tests.sh` の「## 構築(provision_web_server.sh)のテスト」「## 受け入れ試験(build_verify.sh)のテスト」の各アサーションに対応します。B-06は実行環境がrootのときはスキップされ、その旨をテスト結果に残します（`tests/run_tests.sh` 内で `id -u` が0でない場合のみ実行）。

B-09からB-11は、検証環境（コンテナ）にはsystemdもufwも無いため今回は確認できておらず、`NOT RUN` です。実際のUbuntu VMでは、systemdが動くため `systemctl enable --now` は成功し、ufwを導入すれば許可したポートだけに絞り込めると見込んでいますが、これは想定であり実施結果ではありません（検証環境に依存します）。B-12とB-13は自動化しておらず、実行者が結果を読んで判断する「手動」です。

## 実行方法

構築パックのテストとShellCheckは、既存の運用パック（backup・audit）のテストと同じMakeターゲットにまとめて実行されます。構築パック専用の新しいMakeターゲットは追加していません。

```bash
make syntax
make test
make lint
```

- `make syntax` は `bash -n` で `provision_web_server.sh` と `build_verify.sh` を含む全スクリプトの構文を確認します。
- `make test` は `tests/run_tests.sh` を実行し、B-01からB-08を含む全アサーションを1本のスクリプトで流します。
- `make lint` は `shellcheck scripts/*.sh scripts/lib/*.sh tests/*.sh` を実行し、`provision_web_server.sh` と `build_verify.sh` もチェック対象に含まれます（要shellcheckインストール）。

構築後の受け入れ試験そのもの（`build_verify.sh` 本体の使い方）は次のとおりです。詳しい手順は[13. 構築ハンズオン](13-build-hands-on.md)を参照してください。

```bash
sudo bash scripts/provision_web_server.sh --config config/provision.conf.example --execute
bash scripts/build_verify.sh --config config/provision.conf.example --output build-verify.log
python3 scripts/audit_report.py --input build-verify.log --output build-verify.json
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

FAILを隠してPASSに変更しないことが大切です。修正後は新しい実行記録を追加し、どのコミットで直ったかを残します。B-09からB-11のように実行環境が無くて確認できない項目は、判定欄に `NOT RUN` とだけ書き、備考に「検証環境に依存します」など理由を添えてください。実施済みの記録は[08. 検証証跡](08-evidence.md)にまとめます。
