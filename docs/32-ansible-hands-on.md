# 32. Ansibleハンズオン

この章は[検証環境の構築](03-setup.md)で用意したUbuntu VM（検証環境）と、Ansibleを実行できる制御ノード（Ansibleをインストールした自分のPCやWSLなど）がある前提で進めます。対象は`ansible/site.yml`と`ansible/roles/web_server/`です。[構築ハンズオン](13-build-hands-on.md)と同じ演習形式で、1つずつ手を動かします。

## この章の前提

- 設定値の意味は先に[31. Ansibleの基本設計](31-ansible-design.md)を確認してください。
- 制御ノードに`ansible-core`（`ansible-playbook`コマンド）が必要です。導入方法はOSによって異なるため、公式ドキュメントか配布パッケージ管理システム（`pip install ansible-core`など）に従ってください。
- `community.general.ufw`モジュールを使うため、`ansible-galaxy collection install -r ansible/requirements.yml`で追加コレクションを取得します。この操作にはAnsible Galaxyへのネットワーク到達性が必要です。

## 演習1: 在庫ファイルを用意する

`ansible/inventory.example.ini`には実IPも秘密情報も含まれていません。RFC 5737が文書化専用と定義するアドレス帯（`192.0.2.0/24`）だけを例として使っています。実際の検証用VMに合わせて複製し、書き換えます。

```bash
cp ansible/inventory.example.ini ansible/inventory.ini
# ansible/inventory.ini を実際のホスト名/IP・接続ユーザーに書き換える
```

`ansible/inventory.ini`は`.gitignore`で除外済みです。実際の接続先情報をコミットしないでください。

## 演習2: 構文チェックを実行する

```bash
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook --syntax-check ansible/site.yml
```

この検証環境（コンテナ、かつAnsible Galaxyへのネットワークアクセスが遮断されたサンドボックス）で実際に実行した結果は次のとおりです。`pip install ansible-core`自体は成功し、YAMLファイル自体の構文（`site.yml`、`roles/web_server/tasks/main.yml`、`handlers/main.yml`、`defaults/main.yml`）は`python3 -c "import yaml; yaml.safe_load(...)"`で全ファイルが読み込めることを確認しましたが、`ansible-galaxy collection install`はGalaxyへの接続がこの環境のプロキシで許可されておらず失敗しました。結果として`ansible-playbook --syntax-check`は`community.general.ufw`モジュールを解決できず、次のエラーで終了コード4になります。

```text
[ERROR]: couldn't resolve module/action 'community.general.ufw'. This often indicates a
misspelling, missing collection, or incorrect module path.
Origin: ansible/roles/web_server/tasks/main.yml:31:3
```

これはYAMLの構文誤りではなく、コレクション未導入によるモジュール解決エラーです。`tests/run_tests.sh`はこのエラーメッセージ（`community.general`という文字列）を検出した場合はスキップとして扱い、それ以外の構文エラーは通常どおり失敗として報告します。詳しくは[33. Ansibleテスト仕様](33-ansible-test-plan.md)を参照してください。実際にGalaxyへ到達できる制御ノードでは、コレクション導入後に`--syntax-check`が終了コード0になる想定です（**NOT RUN**、今回の検証環境では確認できていません）。

## 演習3: 初期VMに1回目の適用をする

**本番サーバーや共有マシンでは絶対に実行しないでください。** 使い捨てにできる検証用VMで行います。`--check`（Ansible標準のドライラン相当のオプション）で予定を確認してから、実際に適用します。

```bash
ansible-playbook -i ansible/inventory.ini ansible/site.yml --check --diff
ansible-playbook -i ansible/inventory.ini ansible/site.yml
```

1回目の適用では、`PLAY RECAP`の`changed`件数が0より大きくなり、パッケージ導入・サンプルページ配置・ufw許可・systemd登録の各タスクが`changed`として記録される想定です。実際のUbuntu VMでの実行結果は、この検証環境では確認できていません（**NOT RUN**）。適用したら、次を目視で確認してください。

```bash
dpkg -s nginx | head -n 3
cat /var/www/html/index.html
systemctl is-active nginx
ufw status
```

## 演習4: 2回目の適用で冪等性を確認する

同じプレイブックをもう一度適用し、`changed=0`になることを確認します。

```bash
ansible-playbook -i ansible/inventory.ini ansible/site.yml | tee run2.log
```

期待: `PLAY RECAP`の行が`changed=0`になること（例: `ok=6 changed=0 unreachable=0 failed=0`）。apt・template・ufw・systemdの各モジュールは、対象がすでに望ましい状態であれば変更しないため、2回目は何も変えない想定です。この確認も実際のUbuntu VMでは実施できておらず（**NOT RUN**）、[31. Ansibleの基本設計](31-ansible-design.md)の「冪等性の設計」に記載した根拠（各モジュールの仕様）に基づく想定です。

## 演習5: 既存の受け入れ試験を実行する

Ansibleで構築したサーバーに対して、新しいスクリプトを作らず、既存の`build_verify.sh`をそのまま実行します。手順は[構築ハンズオン](13-build-hands-on.md)の演習3とまったく同じです。

```bash
bash scripts/build_verify.sh --config config/provision.conf.example --output ansible-build-verify.log
python3 scripts/audit_report.py --input ansible-build-verify.log --output ansible-build-verify.json
python3 -m json.tool ansible-build-verify.json
```

`config/provision.conf.example`の各キー（`PACKAGE_NAME` / `SERVICE_NAME` / `WEB_ROOT` / `HTTP_PORT` / `HEALTHCHECK_PATH`）は、`ansible/roles/web_server/defaults/main.yml`の変数（`web_server_package_name`等）の既定値と一致するように設計してあるため、設定ファイルを新しく作る必要はありません。期待する結果は[構築案件概要](11-build-project-overview.md)の完成条件4と同じです。

## 覚え方

[用語集・チートシート](09-glossary-cheatsheet.md)にある「受ける・疑う・動かす・確かめる・伝える」の5段階は、Ansible版でも同じ順で使います。

1. **受ける:** `-i ansible/inventory.ini`で接続先を受け取ります。
2. **疑う:** `--syntax-check`と`--check --diff`で、実際に適用する前に内容を確認します。
3. **動かす:** 検証用VMだけに`ansible-playbook`を適用します。
4. **確かめる:** 既存の`build_verify.sh`でパッケージ導入・サービス稼働・配布ファイル・HTTP応答を確かめ、2回目の適用で`changed=0`になることを確認します。
5. **伝える:** `PLAY RECAP`の`changed`件数と、`build_verify.sh`のログ・終了コード、必要なら`audit_report.py`によるJSON証跡で結果を伝えます。
