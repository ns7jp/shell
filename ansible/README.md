# ansible/ ディレクトリについて

ここは[構成の再現性(Ansible)パック](../docs/30-ansible-project-overview.md)（[10. サーバー構築ポートフォリオへの発展計画](../docs/10-server-build-roadmap.md)のPhase 2相当）で追加したAnsibleコードです。`scripts/provision_web_server.sh` と同じ構築内容（nginx導入、サンプルページ配置、ufw許可、systemd登録）を、Ansibleのロールとして再実装しています。

さらに、[セキュリティ強化パック](../docs/40-security-project-overview.md)（同ロードマップの優先度2「セキュリティ」相当）として、専用ユーザー・SSH鍵認証化・sudoers drop-in・ufw既定拒否+許可リスト・自動更新を行う`roles/security_hardening`を追加しています。

詳しい設計・手順・テスト仕様は次のドキュメントを参照してください。

- [30. Ansible構成管理案件概要](../docs/30-ansible-project-overview.md)
- [31. Ansibleの基本設計](../docs/31-ansible-design.md)
- [32. Ansibleハンズオン](../docs/32-ansible-hands-on.md)
- [33. Ansibleテスト仕様](../docs/33-ansible-test-plan.md)
- [40. セキュリティ強化案件概要](../docs/40-security-project-overview.md)
- [41. セキュリティ強化の基本設計](../docs/41-security-design.md)
- [42. セキュリティ強化ハンズオン](../docs/42-security-hands-on.md)
- [43. セキュリティ強化テスト仕様](../docs/43-security-test-plan.md)

## ファイル構成

```text
ansible/
├── inventory.example.ini   在庫ファイルの例（実IP・秘密情報なし）
├── requirements.yml        追加コレクション（community.general / ansible.posix）の一覧
├── site.yml                エントリーポイントのプレイブック（構築プレイ + セキュリティ強化プレイ）
├── roles/web_server/
│   ├── defaults/main.yml   変数の既定値（config/provision.conf.exampleと対応）
│   ├── tasks/main.yml      apt/template/ufw/systemdによる冪等な構築処理
│   ├── handlers/main.yml   サンプルページ更新時のnginx再読込
│   └── templates/index.html.j2  サンプルページのテンプレート
└── roles/security_hardening/
    ├── defaults/main.yml   変数の既定値（config/hardening.conf.exampleと対応）
    ├── tasks/main.yml      user/authorized_key/template/ufw/aptによる冪等な強化処理
    └── templates/          sudoers drop-in、SSHハードニング設定のテンプレート
```

秘密鍵、パスワード、実IPはこのディレクトリにもリポジトリ全体にも保存しません。`ansible/inventory.ini`（実際の接続先を書いたファイル）は作成しても`.gitignore`済みの前提で扱い、コミットしないでください。
