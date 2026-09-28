# 43. セキュリティ強化テスト仕様

## テスト方針

このドキュメントは、[41. セキュリティ強化の基本設計](41-security-design.md)で説明した`harden_server.sh`（強化）・`verify_hardening.sh`（受け入れ試験）・`ansible/roles/security_hardening/`を対象にしたテスト仕様です。[14. 構築テスト仕様](14-build-test-plan.md)がB-番号、[33. Ansibleテスト仕様](33-ansible-test-plan.md)がA-番号を使うのに対し、このドキュメントはH-番号を使います。

自動テストは一時ディレクトリだけを使い、root権限も実際のSSH・sudo・ufw設定も必要としません。**このパックの自動テストは、実際にユーザーを作成したり、実システムの`/etc/ssh`・`/etc/sudoers.d`を変更したりすることは一切ありません。** `SSHD_DROPIN_PATH`・`SUDOERS_DROPIN_PATH`はすべて一時ディレクトリ配下のパスに差し替えてテストします。未実施の項目は誇張せず、`NOT RUN`と明記します。

終了コードの意味は構築パック・Ansibleパックと共通です（`scripts/lib/common.sh`の定義）。

| 終了コード | 定数名 | 意味 |
|---:|---|---|
| 0 | `EXIT_OK` | 正常終了、警告なし |
| 1 | `EXIT_WARNING` | 完了したが警告あり |
| 2 | `EXIT_ERROR` | 入力や権限が不正なため処理を中断（フェイルクローズ） |

## テストケース

| ID | 対象 | 条件 | 期待結果 | 種別 |
|---|---|---|---|---|
| H-01 | harden_server | 正常な設定、ドライラン（`--execute`なし） | 終了0または1（ufwの有無に依存）、出力に`[DRY-RUN]`を含む | 自動 |
| H-02 | harden_server | 正常な設定、ドライラン | `SUDOERS_DROPIN_PATH`・`SSHD_DROPIN_PATH`いずれも作成されない | 自動 |
| H-03 | harden_server | ドライラン | sudoers drop-inの構文検証（`visudo -c`）自体は実行され、ログに残る | 自動 |
| H-04 | harden_server | `ADMIN_USER`未設定 | 終了2、「ADMIN_USER は必須」を含む | 自動 |
| H-05 | harden_server | `ADMIN_SSH_PUBKEY`が不正な形式（`not-a-valid-key`） | 終了2、「ADMIN_SSH_PUBKEY の形式」を含む | 自動 |
| H-06 | harden_server | `ADMIN_USER=root` | 終了2、「ADMIN_USER に root は指定できません」を含む | 自動 |
| H-07 | harden_server | `SSH_PORT=70000`（範囲外） | 終了2、「1 から 65535 の範囲」を含む | 自動 |
| H-08 | harden_server | `SSHD_DROPIN_PATH=/etc`（危険なパス） | 終了2、「重要なシステムディレクトリ」を含む | 自動 |
| H-09 | harden_server | root権限なしで`--execute` | 終了2、「root権限が必要です」を含む（非rootで実行した場合のみ実行するテスト） | 自動 |
| H-10 | verify_hardening | 不正な設定（`SSH_PORT=70000`など） | 終了2 | 自動 |
| H-11 | verify_hardening | 未強化のサーバー相当の設定（存在しないユーザー・drop-inパス） | 終了1、「専用ユーザーが見つかりません」「sudoers drop-in が見つかりません」などの警告を複数含む | 自動 |
| H-12 | harden_server | 実際のUbuntu VMでの`--execute`実行 | ユーザー作成からSSH・sudoers・ufw・自動更新設定まで成功する | NOT RUN |
| H-13 | harden_server / SSH | root無効化・パスワード認証無効化後の実際の鍵ログイン確認 | 別セッションから`ADMIN_USER`で鍵ログインでき、rootへの直接ログインとパスワードログインが拒否される | NOT RUN |
| H-14 | harden_server | 同じ設定で2回実行し、2回目の差分を目視確認 | 2回目の実行で意図しない変更が出ない（冪等性） | 手動 |
| H-15 | `ansible/roles/security_hardening` | YAML自体の構文（`yaml.safe_load`） | 全ファイルが例外なく読み込める | 自動（実施済み） |
| H-16 | `ansible/roles/security_hardening` | `ansible-lint ansible/site.yml` | `community.general.ufw`のモジュール解決失敗（既存のweb_serverロールに起因、A-04と同じ）を除き、命名規約等の指摘がないこと | 自動（実施済み。下記参照） |
| H-17 | `ansible/roles/security_hardening` | 初期状態のUbuntu VMへの適用 | ユーザー作成・SSH・sudoers・ufw・自動更新の各タスクが`changed`として記録される | NOT RUN |
| H-18 | `verify_hardening.sh` | Ansibleで強化したサーバーに対して実行する | Bash版で強化した場合と同じ判定基準で評価できる | NOT RUN（H-17がNOT RUNのため） |

H-01からH-11、H-15、H-16は自動テストとして実施済みです。H-09は実行環境がrootのときはスキップされ、その旨をテスト結果に残します（`tests/run_tests.sh`内で`id -u`が0でない場合のみ実行、B-06と同じ方式）。H-12・H-13・H-17・H-18は実行環境（実VM、鍵ログインを試せる別端末、Ansible実行基盤）が無いため`NOT RUN`です。H-14は自動化しておらず、実行者が結果を読んで判断する「手動」です。

## 実際に確認した結果（この検証環境）

> **実行者:** この節の結果は、2026-09-09 にこのパックを追加した AI 支援セッション（Claude Code、コミット `a111f79`）が、作業用のコンテナで実行したものです。本人が自分の端末や実VMで実行した記録ではありません。[08. 検証証跡](08-evidence.md)の台帳では「記録なし」として扱っています。

この検証環境（コンテナ、`ufw`・`sshd`コマンド・`unattended-upgrades`パッケージは未導入、`visudo`・`useradd`・`usermod`は導入済み）で、実際に実行して確認できた事実だけを記します。

| 確認内容 | 結果 |
|---|---|
| `bash -n scripts/harden_server.sh` / `bash -n scripts/verify_hardening.sh` | 構文エラーなし（確認済み）。 |
| `harden_server.sh`のドライラン | `[DRY-RUN]`表示のみで、`SUDOERS_DROPIN_PATH`・`SSHD_DROPIN_PATH`とも作成されません。sudoers drop-inの構文検証（`visudo -cf`、一時ファイルに対して）は実際に実行され、`sudoers drop-in の構文を確認しました（visudo -c）`というOKログが出力されます（確認済み）。 |
| 危険な設定の拒否 | `ADMIN_USER`未設定、`ADMIN_USER=root`、`ADMIN_SSH_PUBKEY`の不正形式、`SSHD_DROPIN_PATH=/etc`、`SSH_PORT=70000`は、いずれも終了コード2で拒否されます（確認済み）。 |
| root権限のない`--execute` | 終了コード2で拒否されます（この検証セッションは実際にはrootで動いているため、`tests/run_tests.sh`実行時はこのアサーション自体がスキップされ、「harden root requirement check skipped (running as root)」として記録されました。ロジック自体は`provision_web_server.sh`のB-06と同じ実装で、コードレビューで確認できます）。 |
| `verify_hardening.sh`が未強化のサーバーを警告する | `ADMIN_USER`が存在しないユーザー名、`SSHD_DROPIN_PATH`・`SUDOERS_DROPIN_PATH`が存在しないパスの場合、終了コード1で「専用ユーザーが見つかりません」「sudoers drop-in が見つかりません」等の警告が複数記録されます（確認済み）。 |
| `visudo -cf`の実動作 | `opsadmin ALL=(ALL) ALL`という正しい内容を書いた一時ファイルに対して`visudo -cf`を実行すると`parsed OK`（終了コード0）になることを、このセッションで実際に確認しました。 |
| YAML構文（`yaml.safe_load`） | `ansible/site.yml`、`ansible/roles/security_hardening/tasks/main.yml`、`ansible/roles/security_hardening/defaults/main.yml`の全ファイルが例外なく読み込めました（確認済み）。 |
| `ansible-lint ansible/site.yml` | 初回実行で`var-naming[no-role-prefix]`（変数名に`security_hardening_`接頭辞が無い）と`name[casing]`（タスク名がアルファベット小文字始まり）の指摘を実際に受け、変数名をすべて`security_hardening_`接頭辞付きに、該当タスク名を日本語始まりに修正しました。修正後に再実行すると、残る指摘は既存の`web_server`ロールに起因する`community.general.ufw`のモジュール解決失敗（`syntax-check[unknown-module]`、A-04と同一の既知の制限）1件のみです（確認済み）。 |
| `bash tests/run_tests.sh`（本パックのテストを含む全体） | 46件中46件が`ok`で、テスト全体は成功（終了コード0）しました（確認済み）。内訳は運用パック・構築パックの既存テストに加え、H-01からH-11相当のアサーション（harden 9件、verify_hardening 3件程度）と、既存のAnsible構文チェック（スキップ扱い）を含みます。 |
| `ansible-playbook --syntax-check ansible/site.yml` | A-02と同じ理由（`community.general`未導入）で終了コード4になります。エラー内容は`ansible/roles/web_server/tasks/main.yml:31`の`community.general.ufw`解決失敗で、`security_hardening`ロール自体の構文エラーではありません（確認済み）。 |
| 実Ubuntu VMへの適用、実際のSSH鍵ログイン確認、Ansible版の実VM適用 | 実行していません（NOT RUN）。理由は上表のとおりです。 |

## 実行方法

```bash
make syntax
make test
make lint      # 要shellcheck（この検証環境では未導入のため未実施）
ansible-lint ansible/site.yml   # 要ansible-lint
```

- `make syntax`は`bash -n`で`harden_server.sh`と`verify_hardening.sh`を含む全スクリプトの構文を確認します。
- `make test`は`tests/run_tests.sh`を実行し、H-01からH-11を含む全アサーションを1本のスクリプトで流します。
- `make lint`は`shellcheck scripts/*.sh scripts/lib/*.sh tests/*.sh`を実行し、`harden_server.sh`と`verify_hardening.sh`もチェック対象に含まれます。この検証環境には`shellcheck`が導入されておらず、`make lint`自体は実行できませんでした（`command -v shellcheck`が失敗し、要インストールの案内を出して終了コード2で止まります。**NOT RUN**）。

強化・受け入れ試験そのもの（`harden_server.sh`・`verify_hardening.sh`本体の使い方）は次のとおりです。詳しい手順は[42. セキュリティ強化ハンズオン](42-security-hands-on.md)を参照してください。

```bash
sudo bash scripts/harden_server.sh --config config/hardening.conf.example --execute
bash scripts/verify_hardening.sh --config config/hardening.conf.example --output verify-hardening.log
python3 scripts/audit_report.py --input verify-hardening.log --output verify-hardening.json
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

FAILを隠してPASSに変更しないことが大切です。修正後は新しい実行記録を追加し、どのコミットで直ったかを残します。H-12・H-13・H-17・H-18のように実行環境が無くて確認できない項目は、判定欄に`NOT RUN`とだけ書き、備考に「検証環境に依存します」など理由を添えてください。実施済みの記録は[08. 検証証跡](08-evidence.md)にまとめます。
