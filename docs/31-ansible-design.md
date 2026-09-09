# 31. Ansibleの基本設計

## 全体構成

このパックは、[12. 構築の基本設計](12-build-design.md)の`provision_web_server.sh`と**同じ構築内容**を、Ansibleのプレイブックとロールで再実装したものです。構築後の確認は新しく作らず、既存の`build_verify.sh`をそのまま使い回します。

```text
利用者
  └─ ansible-playbook -i inventory.ini site.yml ── 導入・配置・ufw・systemd ── roles/web_server ── パッケージ → Webサーバー一式
         └─ roles/web_server/defaults/main.yml（config/provision.conf.exampleと対応する変数）
既存の受け入れ試験（変更なし）
  └─ build_verify.sh --config config/provision.conf.example ── 確認 ── Webサーバー → OK/WARN判定
         └─ audit_report.py ── 解析 ── 構築ログ → JSON証跡
```

`ansible-playbook`はパッケージ導入、サンプルページ配置、ufw設定、systemd登録までを担当します。`build_verify.sh`はその結果を後から確認するだけで、Bash版で構築したときと処理を変えていません。「作る」役目と「確かめる」役目を分ける方針は、[12. 構築の基本設計](12-build-design.md)と同じです。

## Bash版との対応関係

nginx導入・サンプルページ配置・ufw許可・systemd登録という4つの構築内容は変えず、実装手段だけをシェルコマンドからAnsibleモジュールへ置き換えています。

| 構築内容 | Bash版（`provision_web_server.sh`） | Ansible版（`roles/web_server/tasks/main.yml`） |
|---|---|---|
| パッケージ導入 | `apt-get update` / `apt-get install -y` を`run_or_show`経由で実行 | `ansible.builtin.apt`（`state: present`） |
| サンプルページ配置 | `install -D -m 0644`でheredocの内容を配置 | `ansible.builtin.template`（Jinja2テンプレート`index.html.j2`） |
| ポート許可 | `ufw allow` をポートごとにループ、`ufw --force enable` | `community.general.ufw`（`rule: allow`をループ、続けて`state: enabled`） |
| サービス登録 | `systemctl enable --now` | `ansible.builtin.systemd`（`enabled: true`, `state: started`） |
| 冪等性の担保 | 各コマンド自体が繰り返し実行に強い作りであることに依存 | 各モジュールが「望ましい状態と一致していれば何もしない」ことを判定してから変更する |

Bash版は`run_or_show`によるドライラン（既定で変更せず予定だけ表示）を備えていますが、Ansible版は`--check`モード（Ansible標準のドライラン相当の機能）で同様の確認ができます。両方とも「変更前に予定を確認できる」という設計思想は同じです。

## 変数設計

Ansible変数は、[12. 構築の基本設計](12-build-design.md)の設定ファイルの役割分担と同じ考え方で、`ansible/roles/web_server/defaults/main.yml`の1箇所にまとめています。

| 変数 | 意味 | 既定値 |
|---|---|---|
| `package_name` | 導入するパッケージ名 | `nginx` |
| `service_name` | 有効化・起動するサービス名 | `nginx` |
| `web_root` | 配布ファイルを置く絶対パス | `/var/www/html` |
| `site_title` | サンプルページの`<title>`と見出し | `Sample Portfolio Web Server` |
| `allowed_tcp_ports` | ufwで許可するTCPポートのリスト | `[22, 80]` |
| `http_port` | 受け入れ試験で確認するHTTPポート | `80` |

秘密情報（パスワード、秘密鍵、APIキーなど）はこのロールに存在しません。接続先ホストの情報（IPアドレスや接続ユーザー）は`ansible/inventory.ini`（利用者が作成し、`.gitignore`で除外されるファイル）に分離し、`ansible/inventory.example.ini`にはRFC 5737が文書化専用と定義するアドレス帯（`192.0.2.0/24`）のみを記載しています。実際の秘密情報を暗号化して管理する必要が生じた場合は、Ansible Vaultの導入を別途検討しますが、今回のスコープには含めません。

## 冪等性の設計

冪等性とは、同じ処理を2回実行しても状態が壊れず、同じ結果に落ち着く性質です（[09. 用語集・チートシート](09-glossary-cheatsheet.md)参照）。Ansibleモジュールは「シェルコマンドを直接呼ぶ」のではなく「望ましい状態を宣言し、モジュール側が現在の状態と比較して差分だけを変更する」設計のため、次の理由で2回目の実行は`changed=0`になる想定です。

- `ansible.builtin.apt`は、指定したパッケージがすでに導入済みであれば何もしません。
- `ansible.builtin.template`は、レンダリング結果が既存ファイルと一致していれば書き込みません（内容が同じ限り`changed`になりません）。
- `community.general.ufw`は、指定したルールがすでに存在すれば追加しません。
- `ansible.builtin.systemd`は、すでに`enabled`かつ`started`状態のサービスに対しては何もしません。

この点は`provision_web_server.sh`の冪等性設計（[12. 構築の基本設計](12-build-design.md)の「冪等性の設計」）と目的は同じですが、根拠が異なります。Bash版は「使用するコマンド自体が繰り返し実行に強い」ことに頼っているのに対し、Ansible版は「モジュールが現在の状態を先に確認してから変更するかどうかを判断する」という、より宣言的な仕組みに頼っています。

実際に初期VMへ2回適用し、2回目が`changed=0`になることを確認する作業は、この検証環境（コンテナ、Ansible未導入）では実施できておらず、`NOT RUN`です。詳しくは[30. Ansible構成管理案件概要](30-ansible-project-overview.md)の完成条件5を参照してください。

## 受け入れ試験の再利用

Ansible版で構築したサーバーに対しても、[12. 構築の基本設計](12-build-design.md)で説明した`build_verify.sh`をそのまま使えます。理由は次の2点です。

1. `ansible/roles/web_server/defaults/main.yml`の変数の既定値が、`config/provision.conf.example`の各キーと1対1で一致するように設計してあるため、Ansibleが作るサーバーの状態とBash版が作るサーバーの状態が同じになります。
2. `build_verify.sh`は`dpkg` / `systemctl` / ファイルの存在 / `curl` / `ufw status`という、OS標準コマンドの結果だけで判定しており、構築手段がBashかAnsibleかを問いません。

新しい受け入れ試験スクリプトを作る必要はなく、既存の`scripts/build_verify.sh`と`scripts/audit_report.py`をそのまま「構築後試験」として使います。詳しい手順は[33. Ansibleテスト仕様](33-ansible-test-plan.md)を参照してください。

## セキュリティ設計

- 変数はすべて`ansible/roles/web_server/defaults/main.yml`に分離し、タスクファイル中に値を直書きしません。
- 接続先ホストの情報は`ansible/inventory.ini`（利用者が作成し、`.gitignore`で除外）に分離し、リポジトリに含めるのは`ansible/inventory.example.ini`（文書化専用アドレスのみ）だけです。
- 秘密鍵、パスワード、APIキーなどの秘密情報はこのロールに含めません。将来的に必要になった場合は、Ansible Vaultなどリポジトリ外で鍵を管理できる仕組みを別途検討します。
- `become: true`（root権限への昇格）は`site.yml`のプレイ単位で明示しており、どのタスクが権限昇格を必要とするかを利用者が読める形にしています。
- ufwの設定は「許可するポートを追加する」タスクのみで、拒否ルールや既存ルールの削除は行いません。意図しないアクセス制御の変更を避けるためです。

## 残るリスク

このAnsibleパックは[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)の「Phase 2: 自動化して再現性を示す」に対応する範囲です。次の観点は本パックの範囲外です。

- 実Ubuntu VMへの適用と、2回目適用時の`changed=0`の実機確認（この検証環境にAnsible自体が無いため`NOT RUN`）。
- Ansible Vaultなどによる秘密情報の暗号化管理。
- Ansible Tower/AWXなど、実行そのものを管理する基盤。
- systemd timerやログ通知による継続的な監視、簡易負荷試験、Terraformなどによる検証環境自体の作成（IaC）。

これらは「未実施」であり、実施したかのように書きません。着手する際は[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)の優先度表を参照してください。
