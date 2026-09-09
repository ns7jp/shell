# 40. セキュリティ強化案件概要

## 架空案件

[11. 構築案件概要](11-build-project-overview.md)でNginx構築を、[30. Ansible構成管理案件概要](30-ansible-project-overview.md)で構成の再現性を仕上げた後、同じ会社から続きの相談を受けた想定です。

> Webサーバーは再現性を持って構築できるようになりました。ですが、構築直後のサーバーはSSHがパスワード認証のまま、rootで直接ログインでき、sudoの範囲も決めていません。ファイアウォールもHTTP/SSH以外を意識的に拒否していません。新人でも安全側に倒した既定値でサーバーを強化でき、何を強化したか客観的に確認できるようにしてください。

位置づけとしては、[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)の優先度2「セキュリティ」（専用ユーザー、SSH、sudo、FW、更新方針、権限表）を、実際に動くBashスクリプトとAnsibleロールの両方として実装したものです。[11. 構築案件概要](11-build-project-overview.md)と[30. Ansible構成管理案件概要](30-ansible-project-overview.md)が作った「Webサーバーが動く状態」に対して、このパックは「安全に運用へ引き渡せる状態」を追加します。

## 利用者と困りごと

| 利用者 | 困りごと | この案件での解決 |
|---|---|---|
| 新人担当 | どこまで強化すればよいか基準がなく、SSHやsudoの設定を誤って自分がログインできなくなる不安がある | `harden_server.sh` は既定がドライランで、`--execute`を明示しない限り何も変更しない。sudoers drop-inは配置前に必ず`visudo -c`で構文検証する |
| リーダー | 「最小権限にした」という説明が個人の感覚に依存し、他の担当者が同じ基準で強化できるか分からない | 強化内容を`config/hardening.conf`（Bash版）・`roles/security_hardening/defaults/main.yml`（Ansible版）の変数として1箇所に定義し、誰が実行しても同じ順序・同じ判定になる |
| 監査担当 | 何をもって「強化完了」とするか基準がない | `verify_hardening.sh`がroot無効化・パスワード認証無効化・sudoers構文・ufw既定拒否+許可ルール・専用ユーザーの存在を終了コードで判定する |
| 情報セキュリティ担当 | 公開ポート・sudo権限・自動更新の方針を説明できる資料がない | 本ドキュメントに権限表とポート方針をまとめ、[41. セキュリティ強化の基本設計](41-security-design.md)で理由を説明する |
| 運用担当 | 強化したサーバーを、既存の構築・点検・バックアップにそのまま引き継ぎたい | `verify_hardening.sh`のログは既存の`audit_report.py`でそのままJSON証跡化できる（ログ書式を統一しているため） |

## スコープ

含むものは、専用の管理・作業ユーザーの作成、SSH鍵認証化（パスワード認証無効化）とroot直接ログインの無効化、sudoers drop-inによる最小権限の付与、ufwによる既定拒否+明示的な許可リスト、自動更新（unattended-upgrades）の導入、強化直後の受け入れ試験（`verify_hardening.sh`）、権限表（誰が何をできるか）です。実装はBash版（`scripts/harden_server.sh`）とAnsible版（`ansible/roles/security_hardening/`）の両方で用意し、[12. 構築の基本設計](12-build-design.md)・[31. Ansibleの基本設計](31-ansible-design.md)と同じ「Bash版とAnsible版で同じ構成内容をそろえる」方針を踏襲します。

含まないものは、実際にSSHのroot直接ログインを無効化した状態での再ログイン試験（締め出しの実地確認）、多要素認証（MFA）、侵入検知（IDS/IPS）、SIEM連携、証明書ベースの認証局運用、実際のインターネット公開を前提にした脅威モデリングです。これらは今回のスコープ外ですが、位置づけと今後の方向性は[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)にまとめています。

**このパックは、検証環境（コンテナ、この検証セッション）の実際のSSH・sudo・ufw設定を一切変更しません。** `harden_server.sh`・Ansibleロールとも、生成する設定ファイルの配置先はすべて`config/hardening.conf`／`roles/security_hardening/defaults/main.yml`の変数で指定する絶対パスであり、自動テスト（`tests/run_tests.sh`）は一時ディレクトリのパスに差し替えて実行します。既定値（`/etc/ssh/sshd_config.d/90-hardening.conf`等）は実Ubuntu VMを想定した値で、この検証環境に対して`--execute`を実行したことはありません。

### 設定キー一覧

強化（`harden_server.sh`）と受け入れ試験（`verify_hardening.sh`）は、同じ設定ファイル（`config/hardening.conf.example`）を共有します。これは[12. 構築の基本設計](12-build-design.md)が`provision_web_server.sh`と`build_verify.sh`に採用した設計と同じ理由（「作った内容」と「確認する内容」を常に一致させるため）です。

| キー | 意味 | 既定値の例 | 使うスクリプト |
|---|---|---|---|
| `ADMIN_USER` | 作成する専用の管理・作業ユーザー名 | `opsadmin` | 両方 |
| `ADMIN_SSH_PUBKEY` | `ADMIN_USER`に登録するSSH公開鍵（1行） | （利用者が用意する公開鍵） | `harden_server.sh`のみ |
| `SSHD_DROPIN_PATH` | SSH強化設定を書き出す絶対パス | `/etc/ssh/sshd_config.d/90-hardening.conf` | 両方 |
| `SUDOERS_DROPIN_PATH` | sudoers drop-inを書き出す絶対パス | `/etc/sudoers.d/90-opsadmin` | 両方 |
| `SSH_PORT` | SSHの待受ポート | `22` | 両方 |
| `ALLOWED_TCP_PORTS` | ufwで追加許可するTCPポート（`SSH_PORT`以外、空白区切り） | `80` | 両方 |
| `UNATTENDED_UPGRADES_PACKAGE` | 自動更新に導入するパッケージ名 | `unattended-upgrades` | `harden_server.sh`のみ |

`ADMIN_USER`・`ADMIN_SSH_PUBKEY`は`harden_server.sh`の必須項目です。書き忘れると終了コード2で拒否します。`ADMIN_USER`に`root`は指定できません（専用の非rootユーザーを作る設計のため）。`ADMIN_SSH_PUBKEY`は`ssh-ed25519`/`ssh-rsa`/`ssh-ecdsa-*`形式でない場合、`SSHD_DROPIN_PATH`・`SUDOERS_DROPIN_PATH`が重要なシステムディレクトリそのものの場合、`SSH_PORT`・`ALLOWED_TCP_PORTS`の各値が1〜65535の範囲外の場合、いずれも終了コード2で拒否します（安全側で止める、フェイルクローズ）。

## 権限表（誰が何をできるか）

最小権限の設計根拠を、実装したファイルと対応づけて示します。

| 主体 | できること | できないこと | 根拠（実装） |
|---|---|---|---|
| `ADMIN_USER`（専用ユーザー、例: `opsadmin`） | SSH公開鍵でログインし、`sudo`でパスワード入力のうえ管理コマンドを実行する | パスワードでのSSHログイン、SSH経由でのroot直接ログイン | `sshd_hardening.conf.j2` / `SSHD_DROPIN_PATH`（`PasswordAuthentication no` / `PermitRootLogin no` / `AllowUsers ADMIN_USER`） |
| `root`（システムアカウント） | ローカルコンソールや`sudo -i`経由での作業（強化対象外） | SSH経由での直接ログイン | 同上（`PermitRootLogin no`） |
| `ADMIN_USER`以外の一般ユーザー | このパックの対象外（作成しない） | SSHログイン全般（`AllowUsers`に含まれない） | 同上（`AllowUsers ADMIN_USER`） |
| 手元PC（SSHクライアント） | `SSH_PORT`（既定22/tcp）への接続のみ | `SSH_PORT`と`ALLOWED_TCP_PORTS`以外のポートへの接続 | ufw既定拒否(incoming) + 許可リスト（[41. セキュリティ強化の基本設計](41-security-design.md)参照） |
| 監査担当 | `verify_hardening.sh`の読み取り専用チェックを実行する | サーバー設定の変更（`verify_hardening.sh`は変更を一切行わない） | `scripts/verify_hardening.sh` |
| 自動更新（unattended-upgrades） | セキュリティ更新パッケージの自動適用 | 任意パッケージの無条件アップグレード（配布既定のセキュリティチャンネルのみ） | `UNATTENDED_UPGRADES_PACKAGE`導入（[41. セキュリティ強化の基本設計](41-security-design.md)参照） |

「最小権限」とは、各主体に対して業務上必要な操作だけを許可し、それ以外を既定で拒否することです。上表は「誰が」「何を」できるかを1行ずつに分解し、SSHのログイン制御・ufwのポート制御・sudoの権限付与という3つの制御点それぞれに対応する実装ファイルを明示しています。

## 完成条件

1. 初心者がREADMEから何もこわさずドライランを体験できる。

   ```bash
   cp config/hardening.conf.example config/hardening.conf
   chmod 600 config/hardening.conf
   bash scripts/harden_server.sh --config config/hardening.conf
   ```

   既定は必ずドライランです。ユーザー作成・SSH鍵配置・sudoers drop-in配置・ufw変更・自動更新導入のいずれも実行されず、`[DRY-RUN]`を先頭に付けて表示するだけです。ただし、sudoers drop-inの**構文検証（`visudo -cf`）自体はドライランでも実行**します。構文を確認するだけで対象ファイルへの書き込みは行わないため、安全に検証できます。

2. `--execute`を明示しない限り変更が起きない。

   ```bash
   # 何も変更しない（既定）
   bash scripts/harden_server.sh --config config/hardening.conf

   # 実際に変更する（root権限が必要、検証用VMやコンテナでのみ実行すること）
   sudo bash scripts/harden_server.sh --config config/hardening.conf --execute
   ```

   `--execute`を付けたのにroot権限がない場合は、`provision_web_server.sh`と同じメッセージ（「`--execute にはroot権限が必要です（sudoで実行してください）`」）とともに終了コード2で拒否します。

3. 強化直後に`verify_hardening.sh`で複数項目を客観的に確認できる。

   ```bash
   bash scripts/verify_hardening.sh --config config/hardening.conf --output verify-hardening.log
   ```

   確認する項目と、確認できなかった場合のメッセージは次のとおりです。すべてOKなら終了コード0、1つでもWARNがあれば終了コード1になります。

   | 確認項目 | 確認できない場合のメッセージ |
   |---|---|
   | 専用ユーザーの存在（`id`） | 専用ユーザーが見つかりません |
   | 専用ユーザーが`root`グループに未所属であること | 対象ユーザーが root グループに所属しています（想定外の権限） |
   | SSHのroot直接ログイン無効化（`sshd -T`または設定ファイル） | SSHのroot直接ログイン無効化を確認できません |
   | SSHのパスワード認証無効化 | SSHのパスワード認証無効化を確認できません |
   | sudoers drop-inの構文（`visudo -c`） | sudoers drop-in の構文が不正です／見つかりません |
   | ufw既定拒否(incoming) | ufwの既定拒否(deny incoming)を確認できません |
   | ufw許可ポート（`SSH_PORT`・`ALLOWED_TCP_PORTS`） | 許可ポートを確認できません |

4. 強化ログを既存の`audit_report.py`でJSON証跡化できる。

   `harden_server.sh`と`verify_hardening.sh`のログは、既存の構築・点検スクリプトと同じ書式（`日時 [LEVEL] メッセージ`）で出力するため、新しいPythonスクリプトを作らず、既存の`audit_report.py`をそのまま再利用できます。

   ```bash
   python3 scripts/audit_report.py --input verify-hardening.log --output verify-hardening.json
   ```

5. Ansible版でも同じ構成内容を再現できる。

   `ansible/roles/security_hardening/`は、`scripts/harden_server.sh`と同じ6工程（専用ユーザー作成、SSH鍵登録、sudoers drop-in、SSHハードニング、ufw既定拒否+許可リスト、自動更新導入）を、`user`/`authorized_key`/`template`/`community.general.ufw`/`apt`の各Ansibleモジュールで冪等に実装しています。`ansible/site.yml`に2つ目のプレイとして追加し、構築プレイ（`web_server`ロール）とは意図的に分離しています。

6. 実機VMでの適用・再ログイン確認など、未実施の項目は`NOT RUN`と明記する。

   | 項目 | 状態 | 備考 |
   |---|---|---|
   | 実Ubuntu VMでの`harden_server.sh --execute` | NOT RUN（検証環境に依存します） | この検証環境には`ufw`・`sshd`・`unattended-upgrades`が入っておらず、実際にユーザーを作成すると検証環境自体に変更が入るため、この検証セッションでは意図的に実行していません。 |
   | SSH root無効化・パスワード認証無効化後の実際の再ログイン確認 | NOT RUN | 締め出し（ロックアウト）を避けるため、実際のUbuntu VMで鍵ログインを別セッションから確認したうえで反映する運用が前提です。 |
   | Ansible版（`ansible-playbook`）による実VMへの適用と冪等性確認 | NOT RUN（[30. Ansible構成管理案件概要](30-ansible-project-overview.md)と同じ理由でこの検証環境にAnsible実行基盤が無いため） | `ansible-galaxy collection install -r ansible/requirements.yml`から通しで確認する想定です。 |
   | ufwの実環境でのポート到達性確認 | NOT RUN（検証環境に依存します） | [11. 構築案件概要](11-build-project-overview.md)と同じ理由です。 |

## 作業工程

`要件確認 → 設計 → 実装(Bash/Ansible) → 静的検証 → テスト → ロードマップ更新`

| 工程 | 内容 |
|---|---|
| 要件確認 | 新人でも安全に強化でき、完成を客観的に確認できることを要件にする |
| 設計 | `config/hardening.conf.example`の設定キーと権限表を決める |
| 実装 | `scripts/harden_server.sh`・`scripts/verify_hardening.sh`・`ansible/roles/security_hardening/`を作成する |
| 静的検証 | `bash -n`、`visudo -cf`（生成したsudoers内容の構文検証）、YAML構文（`yaml.safe_load`）、`ansible-lint`を実行する |
| テスト | `tests/run_tests.sh`に「セキュリティ強化(harden_server.sh)のテスト」「セキュリティ受け入れ試験(verify_hardening.sh)のテスト」を追加する |
| ロードマップ更新 | [10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)の到達状況を見直す |

本番作業はこの学習パックの範囲外です。検証環境で成功しても、本番承認を省略できるわけではありません。
