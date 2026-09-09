# 33. Ansibleテスト仕様

## テスト方針

このドキュメントは、[31. Ansibleの基本設計](31-ansible-design.md)で説明した`ansible/site.yml`と`ansible/roles/web_server/`を対象にしたテスト仕様です。[14. 構築テスト仕様](14-build-test-plan.md)がB-番号で構築パック（Bash版）を扱うのに対し、このドキュメントはA-番号でAnsible版を扱います。

構築内容そのもの（nginx導入、サンプルページ配置、ufw許可、systemd登録）はBash版と同じであるため、構築後の受け入れ試験は新しく作らず、既存の`scripts/build_verify.sh`と`scripts/audit_report.py`をそのまま再利用します。Ansible自体は任意導入のツールという位置づけのため、`tests/run_tests.sh`はAnsibleが無い環境やAnsible Galaxyに到達できない環境でも失敗せず、スキップとして報告します（既存の`build_verify.sh`がufw未導入時にWARNとして扱う考え方と同じです）。

終了コードの意味は構築パック（Bash版）と共通です（`scripts/lib/common.sh`の定義）。

| 終了コード | 定数名 | 意味 |
|---:|---|---|
| 0 | `EXIT_OK` | 正常終了、警告なし |
| 1 | `EXIT_WARNING` | 完了したが警告あり |
| 2 | `EXIT_ERROR` | 入力や権限が不正なため処理を中断 |

Ansible本体の終了コード（`ansible-playbook`）は上記とは別の体系で、`0`=成功、`2`=タスク失敗、`4`=構文・モジュール解決エラーなどを表します。本ドキュメントで「終了コード」とだけ書いた場合はどちらの体系か明記します。

## テストケース

| ID | 対象 | 条件 | 期待結果 | 種別 |
|---|---|---|---|---|
| A-01 | `ansible/site.yml` | YAML自体の構文（`python3 -c "import yaml; yaml.safe_load(...)"`） | 全ファイルが例外なく読み込める | 自動 |
| A-02 | `ansible/site.yml` | `ansible-playbook --syntax-check`（ansible-core導入済み、`community.general`未導入） | 終了コード4、エラー内容が`community.general.ufw`のモジュール解決失敗であること（YAML構文誤りでないこと） | 自動（実施済み） |
| A-03 | `ansible/site.yml` | `ansible-playbook --syntax-check`（`ansible-galaxy collection install -r ansible/requirements.yml`で`community.general`導入済み） | 終了コード0 | NOT RUN（この検証環境はGalaxyへのネットワーク到達性が無い） |
| A-04 | `ansible/roles/web_server` | `ansible-lint ansible/site.yml` | `community.general.ufw`のモジュール解決失敗を除き、命名規約等の指摘がないこと | 自動（実施済み。結果は下記参照） |
| A-05 | `ansible/site.yml` | 初期状態のUbuntu VMへの1回目の適用 | `PLAY RECAP`で`changed`件数が0より大きく、パッケージ導入・サンプルページ配置・ufw許可・systemd登録が反映される | NOT RUN |
| A-06 | `ansible/site.yml` | 同じ設定で2回目の適用 | `PLAY RECAP`が`changed=0`になる（冪等性） | NOT RUN |
| A-07 | `ansible`で構築したサーバー | `scripts/build_verify.sh --config config/provision.conf.example`を実行する | Bash版で構築した場合と同じ判定基準（パッケージ導入・サービス稼働・配布ファイル・HTTP応答・ファイアウォール許可）で評価できる | NOT RUN（構築自体がNOT RUNのため） |
| A-08 | `tests/run_tests.sh` | Ansible未導入の環境で自動テストを実行する | 該当テストが`ok`としてスキップされ、テスト全体は失敗しない | 自動（実施済み。下記参照） |
| A-09 | `tests/run_tests.sh` | Ansible導入済みだが`community.general`未導入の環境で自動テストを実行する | 該当テストが`ok`としてスキップされ、テスト全体は失敗しない | 自動（実施済み。下記参照） |

A-08とA-09は同じ`tests/run_tests.sh`内の1つのアサーションが分岐する形で実装しています。この検証環境では実際に`ansible-playbook`が導入済み（今回のセッションで`pip install ansible-core`を実施）かつ`community.general`が未導入の状態のため、A-09の分岐（`community.general`未検出によるスキップ）を実際に確認できました。A-08（ansible-playbookコマンド自体が無い場合のスキップ）は、`command -v ansible-playbook`が失敗するパスとしてコード上に実装していますが、この検証環境ではAnsibleを導入済みにしたため、その分岐自体は自動テストの実行では通っていません（ロジックは`tests/run_tests.sh`のコードレビューで確認できます）。

## 実際に確認した結果（この検証環境）

この検証環境（コンテナ、`ansible-core`は本作業でpip導入、`community.general`はネットワーク制限のため未導入）で、実際に実行して確認できた事実だけを記します。

| 確認内容 | 結果 |
|---|---|
| `pip install ansible-core` | 成功しました（確認済み）。 |
| YAML構文（`yaml.safe_load`によるパース） | `ansible/site.yml`、`ansible/roles/web_server/tasks/main.yml`、`ansible/roles/web_server/handlers/main.yml`、`ansible/roles/web_server/defaults/main.yml`、`ansible/requirements.yml`の全5ファイルが例外なく読み込めました（確認済み）。 |
| `ansible-galaxy collection install -r ansible/requirements.yml` | この検証環境のプロキシがAnsible Galaxyへの接続を許可しておらず、`Tunnel connection failed: 403 Forbidden`で失敗しました（確認済み、環境依存）。 |
| `ansible-playbook --syntax-check ansible/site.yml` | 終了コード4。エラー内容は`community.general.ufw`のモジュール解決失敗で、YAML構文自体のエラーではありませんでした（確認済み）。 |
| `ansible-lint ansible/site.yml` | 変数名の役割プレフィックス規約（`var-naming[no-role-prefix]`）とハンドラー名の大文字始まり規約（`name[casing]`）の指摘を受け、変数名を`web_server_`接頭辞付きに、ハンドラー名を`Reload nginx`に修正しました。修正後に再実行すると、残る指摘は`community.general.ufw`のモジュール解決失敗（`syntax-check[unknown-module]`）1件のみです（確認済み）。 |
| `bash tests/run_tests.sh`（Ansibleテスト部分を含む全体） | 27件中27件が`ok`で、Ansible部分は「`ansible syntax-check skipped (community.general collection not available in this sandbox)`」として記録され、テスト全体は成功（終了コード0）しました（確認済み）。 |
| 実Ubuntu VMへの適用（1回目・2回目）、`build_verify.sh`によるAnsible構築後の受け入れ試験 | 実行していません（NOT RUN、検証用VMと、Galaxyへ到達できる制御ノードが必要です）。 |

## 実行方法

```bash
bash tests/run_tests.sh
```

`tests/run_tests.sh`のAnsible部分は次の順で判定します。

1. `ansible-playbook`コマンドが無ければ、`ok - ansible syntax-check skipped (ansible-playbook not installed)`として記録し、成功扱いにします。
2. `ansible-playbook`があれば`ansible-playbook --syntax-check ansible/site.yml`を実行します。終了コード0なら成功です。
3. 終了コードが0以外でも、エラー内容に`community.general`という文字列を含む場合（コレクション未導入によるモジュール解決失敗）は、YAML自体の構文誤りではないと判断し、`ok - ansible syntax-check skipped (community.general collection not available in this sandbox)`として記録します。
4. それ以外のエラー（YAMLの構文誤りなど）は`not_ok`として記録し、出力を残します。

構築後の受け入れ試験そのもの（`build_verify.sh`によるAnsible構築後の確認）は次のとおりです。詳しい手順は[32. Ansibleハンズオン](32-ansible-hands-on.md)を参照してください。

```bash
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory.ini ansible/site.yml
ansible-playbook -i ansible/inventory.ini ansible/site.yml   # 2回目、changed=0を確認
bash scripts/build_verify.sh --config config/provision.conf.example --output ansible-build-verify.log
python3 scripts/audit_report.py --input ansible-build-verify.log --output ansible-build-verify.json
```

## 証跡テンプレート

```text
テストID:
日時・タイムゾーン:
実行者:
環境(OS/ansible-core/コレクション有無/commit):
実行コマンド:
期待結果:
実結果:
終了コード:
判定(PASS/FAIL/NOT RUN):
ログまたはスクリーンショット:
備考・課題ID:
```

FAILを隠してPASSに変更しないことが大切です。A-05からA-07のように実行環境（実VM、Galaxyへ到達できる制御ノード）が無くて確認できない項目は、判定欄に`NOT RUN`とだけ書き、備考に理由（「検証環境に依存します」「ネットワーク制限のため」など）を添えてください。実施済みの記録は[08. 検証証跡](08-evidence.md)にまとめます。
