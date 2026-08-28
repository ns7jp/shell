# 06. 運用・障害対応手順

## 日次点検

```bash
cd /path/to/shell
git rev-parse --short HEAD
./scripts/server_audit.sh --config /secure/path/audit.conf --output /secure/path/evidence/audit-$(date +%F).log
status=$?
printf 'status=%s\n' "$status"
```

- 0: ログを保存して完了。
- 1: WARN行を抽出し、次の切り分けへ進む。
- 2: 設定、権限、依存コマンドを確認。解決しなければ変更せずエスカレーション。

## 初動の原則

1. **検知:** 何が、いつ、どのホストで起きたか記録する。
2. **影響確認:** 利用者影響、対象範囲、継続中かを確認する。
3. **保全:** ログや現在状態を保存する。慌てて削除・再起動しない。
4. **切り分け:** CPU、メモリ、ディスク、サービス、直近変更の順に確認する。
5. **連絡:** 判断権限を超える操作の前に承認者へ報告する。
6. **復旧確認:** コマンド成功だけでなくサービスの利用確認を行う。

## 症状別チェック

### ディスク警告

```bash
df -hT
sudo du -xhd1 /var 2>/dev/null | sort -h
find /var/log -xdev -type f -size +100M -ls 2>/dev/null
```

勝手にログを削除しません。対象プロセス、保持要件、バックアップ有無を確認し、承認後に対応します。

### サービス停止

```bash
systemctl status SERVICE --no-pager
journalctl -u SERVICE --since '-30 min' --no-pager
systemctl is-enabled SERVICE
```

再起動前にエラーと直近変更を記録します。再起動権限や影響が不明ならエスカレーションします。

### バックアップ失敗

```bash
df -h /backup/path
namei -l /source/path /backup/path
tar -tzf /backup/path/archive.tar.gz
```

失敗したアーカイブを正常品として扱わず、既存の正常世代を削除しません。

## エスカレーション文例

```text
件名: [警告/障害] ホスト名 - 現象 - 検知時刻
影響: 分かっている範囲。不明なら調査中
検知: コマンド、監視、利用者申告
確認済み: 実行コマンドと事実
未実施: 再起動、削除など承認待ち操作
依頼: 判断または作業承認
証跡: ログの保存場所
```

## 定期実行

cronやsystemd timerへの登録例は、環境、実行ユーザー、ロック、通知、ログ保存先を設計してから作ります。本リポジトリでは実環境登録を `NOT RUN` としています。
