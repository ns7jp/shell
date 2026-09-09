# 41. セキュリティ強化の基本設計

## 全体構成

このパックも、[12. 構築の基本設計](12-build-design.md)と同じ「**作る**役目と**確かめる**役目を分ける」設計を踏襲します。

```text
利用者
  ├─ harden_server.sh --config FILE [--execute] ── ユーザー作成・SSH鍵登録・sudoers・ufw・自動更新
  │       └─ scripts/lib/common.sh（ログ、検証、終了コード）
  ├─ verify_hardening.sh --config FILE [--output FILE] ── 確認 ── 強化後のサーバー → OK/WARN判定
  │       └─ scripts/lib/common.sh（ログ、検証、終了コード）
  ├─ ansible/roles/security_hardening/ ── Bash版と同じ6工程をAnsibleモジュールで再実装
  └─ audit_report.py --input FILE --output FILE ── 解析 ── 強化ログ → JSON証跡
```

`harden_server.sh`はユーザー作成、SSH公開鍵登録、sudoers drop-in配置、SSHハードニング設定配置、ufw設定、自動更新導入までを担当します。`verify_hardening.sh`はその結果を後から確認するだけで、何も変更しません。

## ネットワーク構成とポート方針

[12. 構築の基本設計](12-build-design.md)の許可リストを引き継ぎつつ、「既定拒否」を明示します。

```text
手元PC
  └─ SSH(SSH_PORT/tcp) / HTTP(ALLOWED_TCP_PORTSに含まれる場合)
       └─ Ubuntu VM
            ├─ ufw（既定拒否 incoming）── SSH_PORT・ALLOWED_TCP_PORTSのみ明示許可
            ├─ sshd（鍵認証のみ、root無効化）── ADMIN_USERのみAllowUsers
            ├─ sudoers drop-in（ADMIN_USERにALL=(ALL) ALLだが、SSHではroot直接ログイン不可のため
            │    実際の権限行使には必ずADMIN_USERでのログイン+sudoパスワード入力を要する）
            └─ unattended-upgrades（セキュリティ更新の自動適用）
```

**「既定拒否+明示許可」を選んだ理由**は、公開する意図のない全ポートを事故で開けたままにしないためです。`provision_web_server.sh`（[12. 構築の基本設計](12-build-design.md)）はufwに許可ルールを追加するだけで、既定ポリシー（`ufw default deny/allow`）を明示的には設定していませんでした。このパックでは`ufw default deny incoming` / `ufw default allow outgoing`を最初に設定し、そのうえで`SSH_PORT`と`ALLOWED_TCP_PORTS`だけを許可します。これにより「許可した覚えのないポートが開いている」事故を防ぎます。

| ポート/プロトコル | 用途 | 既定の扱い |
|---|---|---|
| `SSH_PORT`/tcp（既定22） | SSH管理用（鍵認証のみ、`ADMIN_USER`限定） | 明示許可 |
| `ALLOWED_TCP_PORTS`に含まれるポート（既定80） | HTTPアクセス用など | 明示許可 |
| それ以外 | - | 既定拒否（incoming）。outgoingは既定許可（パッケージ取得・自動更新のため） |

## 専用ユーザー作成方針

`root`で直接ログインさせず、`ADMIN_USER`という専用の非rootユーザーを作り、日常のログインと`sudo`操作はすべてこのユーザー経由にします。理由は次の3点です。

1. **監査性:** `who`や`last`、`sudo`のログに実行者名が残ります。全員が`root`で作業すると、誰が何をしたか区別できません。
2. **誤操作の抑止:** 常時`root`権限を持つシェルで作業しないため、`sudo`を付け忘れた操作は権限不足で失敗し、意図しない変更に気づきやすくなります。
3. **無効化のしやすさ:** 退職・異動時は`ADMIN_USER`のSSH鍵やアカウントを無効化するだけで済み、`root`自体のパスワードや鍵を回す必要がありません。

`ADMIN_USER`を`root`にできないようにする検証（`harden_server.sh`の`[[ $ADMIN_USER != root ]]`）は、この方針をコードで強制するための安全策です。

## SSH鍵認証化・root無効化の設計

| 設定項目 | 値 | 理由 |
|---|---|---|
| `PasswordAuthentication` | `no` | 総当たり攻撃・パスワード漏えいによる不正ログインを防ぐ。鍵認証は秘密鍵を盗まれない限り突破されにくい |
| `PermitRootLogin` | `no` | rootへ直接ログインできる経路をなくし、必ず`ADMIN_USER`でログイン後に`sudo`を通す |
| `PubkeyAuthentication` | `yes` | 鍵認証を有効にする（`PasswordAuthentication no`と対で設定しないと誰もログインできなくなるため必須） |
| `AllowUsers` | `ADMIN_USER` | ログインできるユーザーをホワイトリスト化し、他の一般ユーザーやサービスアカウントでのSSHログインを防ぐ |
| `Port` | `SSH_PORT`（既定22） | 変数化のみ。ポート変更自体を強い防御策とは位置づけていません（詳しくは[43. セキュリティ強化テスト仕様](43-security-test-plan.md)の残るリスクを参照） |

**設定の反映方法について:** `harden_server.sh`と`security_hardening`ロールは、意図的に`sshd`の再起動・再読込を行いません。設定ミスによってSSH接続自体ができなくなる「締め出し（ロックアウト）」を避けるため、配置後は`sshd -t`で構文検証し、既存セッションを維持したまま別のSSHセッションで新しい鍵ログインを確認してから、運用者が明示的に`systemctl reload sshd`を実行する運用を前提にしています。

## sudoers drop-in の最小権限設計

生成する`sudoers`drop-inは次の1行です（`ADMIN_USER`を`opsadmin`とした例）。

```text
opsadmin ALL=(ALL) ALL
```

**このパックでは、あえて「フルsudo（パスワード入力あり）」を既定にしています。** 理由は次のとおりです。

- コマンドを個別に許可リスト化する設計（例: `opsadmin ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx`のような限定）は、実運用でどのコマンドが必要になるか事前に洗い出す必要があり、洗い出しが不十分だと現場で頻繁に`sudoers`を追記する運用になりがちです。このパックはまだ「どの業務でどのコマンドが必要か」という運用実績が無いため、範囲を絞り込みすぎたsudoers設計を最初から示すのは誠実ではないと判断しました。
- 一方で、**`NOPASSWD`は使わず、必ずパスワード入力を要求**します。SSH鍵を盗まれても、sudoパスワードまでは自動的に奪われないためです（二段階の防御）。
- **最小権限の実践は「フルsudo+パスワード必須+専用ユーザー限定」までとし、コマンド単位の絞り込みは今後の課題として明記します。** 権限行使の主体を`ADMIN_USER`一人に絞り、`root`への直接到達経路（SSH経由の`PermitRootLogin`）を断つことが、このパックにおける最小権限の中心的な実装です。

`harden_server.sh`は生成した`sudoers`drop-inの内容を、配置前に必ず`visudo -cf`（一時ファイルに対する構文検証）で確認します。構文が壊れた状態のファイルを`/etc/sudoers.d/`へ配置すると、対象サーバーの`sudo`コマンドそのものが機能しなくなる重大な事故につながるため、**ドライランであってもこの構文検証だけは実行**します（ファイルへの書き込みは行わず、検証のみです）。Ansible版でも`community.general`を使わない標準機能で、配置前の`ansible.builtin.command: visudo -cf`と、`template`モジュールの`validate: 'visudo -cf %s'`オプションの2段階で同じ検証を行っています。

## 自動更新・更新方針

`unattended-upgrades`パッケージを導入します。Ubuntu/Debian系のセキュリティ更新（`-security`チャンネル）を自動適用する標準的な仕組みで、次の理由で採用しました。

- 新人が「手動でapt upgradeを定期的に回す」運用に頼ると、実施忘れが起きやすく、既知の脆弱性が長期間放置されるリスクがあります。
- `unattended-upgrades`はディストリビューションが提供する既定の安全策で、追加の監視基盤なしに最低限のセキュリティ更新を継続できます。
- 一方で、**カーネル更新や一部パッケージは再起動が必要**になる場合があり、自動更新だけでは「再起動待ち」の状態を検知できません。この点は[43. セキュリティ強化テスト仕様](43-security-test-plan.md)の残るリスクに明記し、`server_audit.sh`等による定期点検（既存の運用パック）と組み合わせる前提です。
- 全パッケージの自動更新ではなく、セキュリティ更新に限定するのがUbuntu既定の`unattended-upgrades`の挙動です。機能追加を伴う通常更新まで自動化すると、動作確認なしに互換性が崩れるリスクがあるため、意図的に既定の設定（セキュリティ更新のみ）から変更していません。

## ufw既定拒否+許可リストの設計

`harden_server.sh`と`security_hardening`ロールは、次の順序でufwを設定します。

1. `ufw default deny incoming` （既定拒否。何も許可しなければ、すべての着信を拒否する状態にする）
2. `ufw default allow outgoing` （パッケージ取得や自動更新のため、発信は既定許可のままにする）
3. `ufw allow SSH_PORT/tcp` （SSH管理用を明示許可）
4. `ALLOWED_TCP_PORTS`の各ポートを`ufw allow PORT/tcp`で明示許可
5. `ufw --force enable` （設定を反映）

**許可の追加のみを行い、既存ルールの削除や拒否ルールの個別追加は行いません。** [31. Ansibleの基本設計](31-ansible-design.md)のセキュリティ設計にある「意図しないアクセス制御の変更を避ける」方針を、Bash版・Ansible版の両方で踏襲しています。

## Bash版とAnsible版の対応関係

| 強化内容 | Bash版（`harden_server.sh`） | Ansible版（`roles/security_hardening/tasks/main.yml`） |
|---|---|---|
| 専用ユーザー作成 | `useradd -m -s /bin/bash` / `usermod -aG sudo` を`run_or_show`経由で実行 | `ansible.builtin.user`（`groups: sudo`, `append: true`） |
| SSH鍵登録 | `install -d` / `install -m 0600`でauthorized_keysを配置 | `ansible.posix.authorized_key` |
| sudoers drop-in | ヒアドキュメントで生成し、`visudo -cf`で検証してから`install -m 0440` | `ansible.builtin.template`（`validate: 'visudo -cf %s'`）、配置前に別途`visudo -cf`でも検証 |
| SSHハードニング | ヒアドキュメントで`sshd_config`のdrop-inを生成し`install -D -m 0644` | `ansible.builtin.template`（`sshd_hardening.conf.j2`） |
| ufw既定拒否+許可 | `ufw default deny/allow` → `ufw allow`をループ → `ufw --force enable` | `community.general.ufw`を複数回呼び出し（`default`/`rule: allow`をループ/`state: enabled`） |
| 自動更新 | `apt-get install unattended-upgrades` | `ansible.builtin.apt` + `ansible.builtin.systemd`で有効化 |

いずれもBash版は`run_or_show`によるドライラン、Ansible版は`--check`モードで、変更前に予定を確認できる設計は[31. Ansibleの基本設計](31-ansible-design.md)と同じです。

## 冪等性の設計

- `useradd`はユーザーがすでに存在する場合、`harden_server.sh`側で`id -u`により事前判定してスキップします（`useradd`自体を重複実行すると失敗するため、Bash版はコマンド実行前に必ず存在確認します）。
- `ansible.builtin.user`はモジュール自身が現在の状態と比較するため、すでに望ましい状態なら`changed`になりません。
- `authorized_keys`・sudoers drop-in・SSHハードニング設定は、いずれも`install`/`template`で毎回同じ内容を安全に上書きするため、2回実行しても壊れません。
- `ufw allow`・`ufw default`は同じ値に対して重複実行しても安全です。
- `apt-get install`・`ansible.builtin.apt`は導入済みパッケージに対して実質何もしません。

## セキュリティ設計

- `--execute`には常にroot権限を要求し、root以外なら終了コード2で拒否します（`provision_web_server.sh`と同じ設計）。
- `ADMIN_USER`は許可した文字種の正規表現でのみ受け付け、`root`を明示的に拒否します。
- `ADMIN_SSH_PUBKEY`は`ssh-ed25519`/`ssh-rsa`/`ssh-ecdsa-*`形式の正規表現でのみ受け付け、任意の文字列を鍵として登録しません。
- `SSHD_DROPIN_PATH`・`SUDOERS_DROPIN_PATH`は`require_absolute_safe_path`で、絶対パスであることと重要なシステムディレクトリそのものでないことを確認します。
- `SSH_PORT`・`ALLOWED_TCP_PORTS`の各値は`require_integer_range`で1〜65535の整数であることを検証します。
- sudoers drop-inは配置前に必ず`visudo -cf`で構文検証し、壊れた内容を`/etc/sudoers.d/`へ書き込みません。
- SSHの再起動・再読込は自動で行わず、締め出し事故を避けます。
- 設定ファイルの所有者・書込権限は`load_config`（`scripts/lib/common.sh`）で確認します（既存スクリプトと共通）。
- コマンド引数は`--`と引用符で保護し、`eval`は使用しません。
- 既定の実行は常にドライランで、`--execute`を明示した場合だけ変更を行います。

## 残るリスク

このパックは[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)の優先度2「セキュリティ」に対応する範囲です。次の観点は本パックの範囲外です。

- sudoコマンド単位の細かい権限絞り込み（現状は「専用ユーザー限定のフルsudo+パスワード必須」まで）。
- 多要素認証（MFA）、証明書ベースのSSH認証局運用。
- カーネル更新後の再起動要否の検知・自動再起動（`unattended-upgrades`はパッケージ更新のみを自動化し、再起動判断は含みません）。
- 侵入検知（IDS/IPS）、ログの集中監視・SIEM連携。
- 実際のSSH再ログイン確認（締め出しの実地検証）、実Ubuntu VMへの適用（[40. セキュリティ強化案件概要](40-security-project-overview.md)の完成条件6に記載の`NOT RUN`項目）。

これらは「未実施」であり、実施したかのように書きません。着手する際は[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)の優先度表を参照してください。
