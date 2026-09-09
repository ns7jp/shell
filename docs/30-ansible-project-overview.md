# 30. Ansible構成管理案件概要

## 架空案件

[11. 構築案件概要](11-build-project-overview.md)でNginx構築を手作業（Bashのドライラン運用）まで仕上げた後、同じ会社から続きの相談を受けた想定です。

> `provision_web_server.sh` のおかげで、手順に自信を持って構築できるようになりました。ですが、実行するのは結局いつも同じ担当者で、他の人が同じ手順を再現できるかは分かりません。初期状態のVMから、誰が実行しても同じ状態に構成できるようにしてください。

位置づけとしては、[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)の「Phase 2: 自動化して再現性を示す」を、実際に動くAnsibleコードとして実装したものです。[11. 構築案件概要](11-build-project-overview.md)は「Ansible等の構成管理は今回のスコープ外」と明記していましたが、本パックがその続きにあたります。

## 利用者と困りごと

| 利用者 | 困りごと | この案件での解決 |
|---|---|---|
| 新人担当 | 手順書どおりに操作したつもりでも、順序や打ち間違いで結果がずれる不安がある | `ansible/site.yml` を実行するだけで、apt・template・ufw・systemdの各モジュールが同じ順序で処理する |
| リーダー | 構築担当者が変わっても同じ結果になるか確認する手段がない | 同じプレイブックを初期VMへ適用し、2回目の実行が`changed=0`になることで再現性を示す |
| 監査担当 | Ansibleが「変更した」と言っているだけで、実際にサーバーが完成条件を満たしたか分からない | 構築後に既存の`scripts/build_verify.sh`をそのまま受け入れ試験として実行し、Bash版と同じ基準で判定する |
| 情報セキュリティ担当 | 構成管理コードに秘密情報やIPアドレスが紛れ込んでいないか心配 | 変数はすべて`ansible/roles/web_server/defaults/main.yml`に分離し、`ansible/inventory.example.ini`は文書化専用アドレス（192.0.2.0/24）のみを使う |

## スコープ

含むものは、`ansible/`配下のプレイブックとロール（`site.yml` / `roles/web_server`）による、nginx導入、静的サンプルページの配置、ufwによるポート許可、systemdへのサービス登録です。対象とする構成内容は[11. 構築案件概要](11-build-project-overview.md)の`provision_web_server.sh`と同じにそろえ、Bash版とAnsible版のどちらで構築しても`build_verify.sh`が同じ基準で判定できるようにしています。

含まないものは、Ansible Vaultなどによる秘密情報の暗号化管理、Ansible Tower/AWXなどの実行基盤、複数ロールにまたがる大規模な構成、クラウドやTerraformによるVM自体の作成です。これらは今回のスコープ外です。特に秘密情報の管理は、今回は「秘密情報を保存しない」設計にとどめ、実際に秘密情報（DBパスワード等）を扱う構成が必要になった時点で、Vault導入をあらためて検討する前提です。

### 変数一覧

`ansible/roles/web_server/defaults/main.yml` は、`config/provision.conf.example`と同じ意味・同じ既定値のキーをAnsible変数として持ちます。

| 変数 | 意味 | 既定値 | `config/provision.conf.example`の対応キー |
|---|---|---|---|
| `package_name` | 導入するパッケージ名 | `nginx` | `PACKAGE_NAME` |
| `service_name` | 有効化・起動するサービス名 | `nginx` | `SERVICE_NAME` |
| `web_root` | 配布ファイルを置く絶対パス | `/var/www/html` | `WEB_ROOT` |
| `site_title` | サンプルページのタイトル | `Sample Portfolio Web Server` | `SITE_TITLE` |
| `allowed_tcp_ports` | ufwで許可するTCPポートのリスト | `[22, 80]` | `ALLOWED_TCP_PORTS`（空白区切り文字列をリストに置き換え） |
| `http_port` | 受け入れ試験で確認するHTTPポート | `80` | `HTTP_PORT` |

構築後の受け入れ試験は、これらのAnsible変数を新しい設定ファイルへ書き写す必要がなく、既存の`config/provision.conf.example`をそのまま`build_verify.sh`に渡せます。値をそろえてあるためです。

## 完成条件

1. 初期状態のVMにプレイブックを適用し、変更内容を記録する。

   ```bash
   ansible-galaxy collection install -r ansible/requirements.yml
   ansible-playbook -i ansible/inventory.ini ansible/site.yml
   ```

   1回目の実行では、パッケージ導入・サンプルページ配置・ufw許可・systemd登録のタスクが`changed`として記録されます。

2. 2回目の適用で不要な変更が出ないことを確認する（冪等性）。

   ```bash
   ansible-playbook -i ansible/inventory.ini ansible/site.yml
   ```

   2回目の実行結果（`PLAY RECAP`）が`changed=0`になることを確認します。apt・template・ufw・systemdの各モジュールは、対象がすでに望ましい状態であれば何もしない設計のため、シェルコマンドを直接呼ぶよりも冪等性を保ちやすくなります。

3. 設定値を変数へ分離し、秘密情報を保管しない。

   `ansible/roles/web_server/defaults/main.yml`にすべての設定値をまとめ、`ansible/inventory.example.ini`には実IPやパスワードを書きません。実際の接続先（`ansible/inventory.ini`）は`.gitignore`で除外し、コミットしない運用にします。

4. 本リポジトリの監査スクリプトを配置し、構築後試験として実行する（`build_verify.sh`を再利用する）。

   ```bash
   bash scripts/build_verify.sh --config config/provision.conf.example --output ansible-build-verify.log
   python3 scripts/audit_report.py --input ansible-build-verify.log --output ansible-build-verify.json
   ```

   Ansibleで構築したサーバーに対しても、Bash版で構築したときと同じ`build_verify.sh`と同じ`config/provision.conf.example`をそのまま使えます。新しい受け入れ試験スクリプトは作っていません。詳しい手順は[33. Ansibleテスト仕様](33-ansible-test-plan.md)を参照してください。

5. 実機VMでの適用や冪等性確認など、未実施の項目は`NOT RUN`と明記する。

   | 項目 | 状態 | 備考 |
   |---|---|---|
   | 実Ubuntu VMへの`ansible-playbook`適用（1回目・2回目） | NOT RUN（この検証環境にAnsibleが未導入） | この検証環境（コンテナ）には`ansible-playbook`コマンドが無く、実行できませんでした。実際のUbuntu VMと制御ノードを用意し、`ansible-galaxy collection install`から通しで確認する想定です。 |
   | `ansible-lint`による静的検証 | NOT RUN（この検証環境に未導入） | 同上の理由で、`ansible-lint ansible/site.yml`は実行できていません。 |
   | `ansible-playbook --syntax-check` | NOT RUN（この検証環境に未導入。`tests/run_tests.sh`は自動でスキップを報告） | Ansible本体が無い環境では構文チェックすら実行できないため、`tests/run_tests.sh`はAnsible未導入を検出した場合にこのテストを`ok - ansible syntax-check skipped (ansible-playbook not installed)`として記録し、失敗扱いにはしません。 |

## 作業工程

`要件確認 → 設計 → 実装 → 静的検証(--syntax-check/ansible-lint) → テスト(tests/run_tests.sh) → 実機での適用(NOT RUN) → 冪等性確認(NOT RUN) → 受け入れ試験(build_verify.sh) → 証跡 → ロードマップ更新`

| 工程 | 内容 |
|---|---|
| 要件確認 | 初期VMから同じ状態を再現でき、2回目の適用で余計な変更が出ないことを要件にする |
| 設計 | `ansible/roles/web_server/defaults/main.yml`の変数と、`config/provision.conf.example`との対応を決める |
| 実装 | `ansible/site.yml`と`ansible/roles/web_server/`（tasks/handlers/templates/defaults）を作成する |
| 静的検証 | `ansible-playbook --syntax-check`、可能なら`ansible-lint`でYAMLとタスク定義を確認する |
| テスト | `tests/run_tests.sh`にAnsibleの構文チェックを組み込み、Ansible未導入環境では明示的にスキップする |
| 実機での適用 | 実Ubuntu VMに1回目の適用を行い、変更内容を記録する（今回は`NOT RUN`） |
| 冪等性確認 | 同じプレイブックを2回目適用し、`changed=0`を確認する（今回は`NOT RUN`） |
| 受け入れ試験 | 既存の`build_verify.sh`を、Ansibleで構築したサーバーに対しても実行する |
| 証跡 | `audit_report.py`でログをJSON証跡化する |
| ロードマップ更新 | [10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)の到達状況を見直す |

本番作業はこの学習パックの範囲外です。検証環境で成功しても、本番承認を省略できるわけではありません。
