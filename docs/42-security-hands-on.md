# 42. セキュリティ強化ハンズオン

この章は[検証環境の構築](03-setup.md)で用意したUbuntu VM（検証環境）がすでにある前提で進めます。対象は「強化する」`scripts/harden_server.sh`と、「強化できたか確認する」`scripts/verify_hardening.sh`の2本です。[構築ハンズオン](13-build-hands-on.md)と同じ演習形式で、1つずつ実際に手を動かします。

## この章の前提

- 設定キーと権限表の意味は先に[41. セキュリティ強化の基本設計](41-security-design.md)を確認してください。
- **`--execute`は必ず使い捨ての検証用VMやコンテナで行い、本番サーバーや共有マシン、日常使っている端末では絶対に実行しないでください。** SSHのroot無効化・パスワード認証無効化は、鍵ログインの準備ができていないと自分自身を締め出す可能性があります。
- 終了コードの意味は構築パックと共通です。

| 終了コード | 意味 |
|---:|---|
| 0 | 正常（`EXIT_OK`、警告なし） |
| 1 | 警告あり（`EXIT_WARNING`） |
| 2 | 実行エラー（`EXIT_ERROR`。設定不備や安全でない値の拒否を含みます） |

## 演習1: ドライランで出力を読む

まず設定ファイルを用意します。`ADMIN_SSH_PUBKEY`は自分が実際に持っている公開鍵（`~/.ssh/id_ed25519.pub`等）に書き換えるのが望ましいですが、ドライランだけを試す場合は既定値のままでも構いません。

```bash
cp config/hardening.conf.example config/hardening.conf
chmod 600 config/hardening.conf
./scripts/harden_server.sh --config config/hardening.conf
```

`--execute`を付けなければ既定でドライランです。何も変更されず、実行予定のコマンドだけが表示されます。ただし、sudoers drop-inの構文検証（`visudo -cf`）だけは、ファイルへの書き込みを伴わないためドライランでも実際に実行されます。

```text
2026-09-09T00:00:00+0000 [INFO] サーバーのセキュリティ強化を開始します
2026-09-09T00:00:00+0000 [INFO] 対象ユーザー: opsadmin / SSHポート: 22 / 追加許可ポート: 80
2026-09-09T00:00:00+0000 [INFO] ユーザーを作成します: opsadmin
[DRY-RUN] useradd -m -s /bin/bash -- opsadmin
[DRY-RUN] usermod -aG sudo -- opsadmin
2026-09-09T00:00:00+0000 [INFO] 公開鍵を用意しました: /home/opsadmin/.ssh/authorized_keys
[DRY-RUN] install -d -m 0700 -o opsadmin -g opsadmin -- /home/opsadmin/.ssh
[DRY-RUN] install -m 0600 -o opsadmin -g opsadmin -- /tmp/xxxxxx /home/opsadmin/.ssh/authorized_keys
2026-09-09T00:00:00+0000 [OK] sudoers drop-in の構文を確認しました（visudo -c）
[DRY-RUN] install -m 0440 -- /tmp/xxxxxx /etc/sudoers.d/90-opsadmin
2026-09-09T00:00:00+0000 [INFO] SSH強化設定を用意しました: /etc/ssh/sshd_config.d/90-hardening.conf
[DRY-RUN] install -D -m 0644 -- /tmp/xxxxxx /etc/ssh/sshd_config.d/90-hardening.conf
[DRY-RUN] ufw default deny incoming
[DRY-RUN] ufw default allow outgoing
[DRY-RUN] ufw allow 22/tcp
[DRY-RUN] ufw allow 80/tcp
[DRY-RUN] ufw --force enable
[DRY-RUN] env DEBIAN_FRONTEND=noninteractive apt-get update
[DRY-RUN] env DEBIAN_FRONTEND=noninteractive apt-get install -y -- unattended-upgrades
2026-09-09T00:00:00+0000 [INFO] ドライラン完了。内容を確認後、検証環境で --execute を指定してください
2026-09-09T00:00:00+0000 [OK] セキュリティ強化完了: 警告なし
```

問い: `visudo`が入っていない環境で同じドライランを実行すると、`require_command visudo`が起動直後に失敗し、終了コード2で停止します。`ufw`が入っていない環境ではどうなるでしょうか。`provision_web_server.sh`と同じ方針で、`ufw`が見つからない場合は致命的エラーにせず、「`ufw が見つからないためファイアウォール設定をスキップしました（手動確認が必要）`」というWARNを1件加えて処理を続けます。

期待: `ls /etc/sudoers.d/90-opsadmin`が「そのようなファイルはありません」となること（ドライランでは何も作成されません）。

## 演習2: 検証用VMやコンテナで実際に強化する

`--execute`を付けると、実際にユーザーを作成し、SSH・sudoers・ufw・自動更新の設定を変更します。**本番サーバーや共有マシンでは絶対に実行しないでください。**

```bash
sudo ./scripts/harden_server.sh --config config/hardening.conf --execute
echo "終了コード=$?"
```

実行後、**同じSSHセッションを切断する前に**、別の新しいターミナルから鍵ログインを確認します。

```bash
ssh -i ~/.ssh/id_ed25519 opsadmin@<検証VMのIP>
```

鍵ログインが成功し、`sudo -l`で権限を確認できてから、初めて元のセッションを閉じてください。ここで確認せずに元のセッションを閉じると、設定ミスがあった場合にサーバーへ再接続できなくなる可能性があります（締め出し）。

実行後、次を目視で確認します。

```bash
id opsadmin
cat /etc/sudoers.d/90-opsadmin
sudo sshd -t
sudo ufw status verbose
systemctl is-enabled unattended-upgrades
```

`sshd -t`は設定ファイルの構文チェックのみで、実際の再読込は行いません。設定を反映するには、鍵ログインを確認した後に`sudo systemctl reload sshd`を明示的に実行してください（`harden_server.sh`は意図的にこれを自動実行しません）。

## 演習3: 受け入れ試験の結果をJSON証跡にする

`verify_hardening.sh`は強化後の受け入れ試験です。使い方は[構築ハンズオン](13-build-hands-on.md)の演習3（`build_verify.sh`）とまったく同じ流れです。

```bash
./scripts/verify_hardening.sh --config config/hardening.conf --output "$PWD/verify-hardening.log"
python3 scripts/audit_report.py --input "$PWD/verify-hardening.log" --output "$PWD/verify-hardening.json"
status=$?
python3 -m json.tool "$PWD/verify-hardening.json"
printf '変換終了コード=%s\n' "$status"
```

期待: `sshd`を再読込する前は`PermitRootLogin no`が設定ファイル上に存在してもまだ有効になっていない場合があるため、`verify_hardening.sh`は`sshd -T`（実際に有効な設定）が使える環境ではそちらを優先して確認します。`sshd`コマンド自体が無い環境（この検証環境を含む）では、設定ファイルの中身を直接確認し、その旨をログに残します。

## 演習4: わざと失敗させる

`ADMIN_USER`を`root`に書き換えて実行します。

```bash
cp config/hardening.conf config/hardening_danger.conf
sed -i 's|^ADMIN_USER=.*|ADMIN_USER=root|' config/hardening_danger.conf
./scripts/harden_server.sh --config config/hardening_danger.conf
echo "終了コード=$?"
```

期待: 「`ADMIN_USER に root は指定できません（専用の非rootユーザーを作成してください）`」というメッセージとともに、終了コード2で拒否されます。

同様に、`ADMIN_SSH_PUBKEY`を`not-a-key`のような不正な形式に書き換えると、「`ADMIN_SSH_PUBKEY の形式が正しくありません`」というメッセージとともに終了コード2で拒否されます。`SSHD_DROPIN_PATH`や`SUDOERS_DROPIN_PATH`に`/etc`のような重要ディレクトリそのものを指定した場合も同様に拒否されます。どちらの確認も`--execute`を付けずに行えます。

## 演習5: sudoers drop-inの構文検証を体験する

`harden_server.sh`が生成するsudoers drop-inは、ドライランでも`visudo -cf`により実際に構文検証されます。この動作を手元で再現するには、次のように一時ファイルへ同じ内容を書いて確認できます。

```bash
tmp_sudoers=$(mktemp)
printf 'opsadmin ALL=(ALL) ALL\n' >"$tmp_sudoers"
visudo -cf "$tmp_sudoers"
echo "終了コード=$?"
rm -f "$tmp_sudoers"
```

期待: `parsed OK`と表示され、終了コード0になります。試しに`opsadmin ALL=(ALL) ALL件`のように余計な文字を混ぜると、`visudo`が構文エラーを検出し、終了コード1になります。`harden_server.sh`はこの検証に失敗した場合、配置せずWARNを記録します。

## Ansible版を試す

`ansible/roles/security_hardening/`は、上と同じ強化内容をAnsibleで再現します。手順は[32. Ansibleハンズオン](32-ansible-hands-on.md)とほぼ同じです。

```bash
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory.ini ansible/site.yml --tags security_hardening --check --diff
```

（`site.yml`は構築プレイと強化プレイの2つに分かれているため、`--tags`ではなく`ansible-playbook ansible/site.yml --limit web --start-at-task ...`のようにプレイ単位で選ぶ方法もあります。強化だけを個別に試したい場合は、`ansible/site.yml`から該当プレイだけを抜き出した一時プレイブックを作るか、`--ask-become-pass`を付けて全体を適用してから`verify_hardening.sh`で確認してください。）

この検証環境では、`community.general`コレクションがAnsible Galaxyへのネットワーク制限のため導入できておらず、`--syntax-check`は`community.general.ufw`のモジュール解決で終了コード4になります（YAML構文自体のエラーではありません）。詳しくは[43. セキュリティ強化テスト仕様](43-security-test-plan.md)を参照してください。

## 覚え方

[用語集・チートシート](09-glossary-cheatsheet.md)にある「受ける・疑う・動かす・確かめる・伝える」の5段階は、セキュリティ強化でも同じ順で使います。

1. **受ける:** `--config`で設定ファイルを受け取ります。
2. **疑う:** `ADMIN_USER`・`ADMIN_SSH_PUBKEY`・各パス・各ポートを検証し、危険な値は終了コード2で拒否します。sudoers drop-inは配置前に必ず`visudo -c`で構文検証します。
3. **動かす:** ドライランで内容を確認してから、検証用VMやコンテナだけで`--execute`を動かします。SSHは締め出しを避けるため、反映（再読込）は自動化しません。
4. **確かめる:** `verify_hardening.sh`でroot無効化・パスワード認証無効化・sudoers構文・ufw既定拒否+許可・専用ユーザーを確かめます。
5. **伝える:** ログと終了コード、必要なら`audit_report.py`によるJSON証跡、[権限表](40-security-project-overview.md#権限表誰が何をできるか)で結果を伝えます。
