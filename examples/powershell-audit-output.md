# PowerShell点検出力の読み方

`scripts/powershell/Invoke-ServerAudit.ps1` は、Bash版の `server_audit.sh` と**まったく同じ書式**でログを出します。だから、Bash版のために作った `scripts/audit_report.py` をそのままJSON証跡化に使えます。

## Windows Serverでの出力（説明用の例）

```text
2026-01-01T09:00:00+0900 [INFO] サーバー点検を開始します
2026-01-01T09:00:00+0900 [INFO] ホスト名: WIN-PORTFOLIO
2026-01-01T09:00:00+0900 [INFO] OS: Microsoft Windows 10.0.20348
2026-01-01T09:00:00+0900 [INFO] PowerShell: 7.4.6
2026-01-01T09:00:01+0900 [OK] CPU使用率: 12% (しきい値: 80%)
2026-01-01T09:00:01+0900 [OK] メモリ使用率: 46% (しきい値: 80%)
2026-01-01T09:00:01+0900 [WARN] ディスク使用率 C: 85% (しきい値: 80%)
2026-01-01T09:00:01+0900 [OK] サービス稼働: W32Time
2026-01-01T09:00:02+0900 [OK] システムイベントログのエラー: 直近24時間で0件 (しきい値: 1件)
2026-01-01T09:00:02+0900 [OK] ログディレクトリ読取可能: C:\ProgramData\ops-lab\logs
2026-01-01T09:00:02+0900 [WARN] 点検完了: 警告 1 件
```

これは説明用の架空例であり、実サーバーの実行証跡ではありません。上の行のうち、Windows実機でしか得られない値（`Get-CimInstance` によるCPU・メモリ、`Get-Service`、`Get-WinEvent`）は、[検証証跡](../docs/08-evidence.md)で `NOT RUN` として扱っています。

`INFO` は情報、`OK` は基準内、`WARN` は確認が必要、`ERROR` は処理継続不能を表します。

## Linux（PowerShell 7）での実際の出力

こちらは**このリポジトリの検証環境で実際に実行した結果**です。Windows専用のコマンドが存在しないため、その2項目が `WARN` になっています。

```text
2026-09-03T06:19:30+0000 [INFO] サーバー点検を開始します
2026-09-03T06:19:30+0000 [INFO] ホスト名: vm
2026-09-03T06:19:30+0000 [INFO] OS: Ubuntu 24.04.4 LTS
2026-09-03T06:19:30+0000 [INFO] PowerShell: 7.4.6
2026-09-03T06:19:30+0000 [OK] CPU使用率: 1% (しきい値: 80%)
2026-09-03T06:19:30+0000 [OK] メモリ使用率: 4% (しきい値: 80%)
2026-09-03T06:19:30+0000 [OK] ディスク使用率 /: 88% (しきい値: 95%)
2026-09-03T06:19:30+0000 [WARN] Get-Service が無いためサービス状態を確認できません(Windows以外の環境です)
2026-09-03T06:19:30+0000 [WARN] Get-WinEvent が無いためイベントログを確認できません(Windows以外の環境です)
2026-09-03T06:19:30+0000 [OK] ログディレクトリ読取可能: /home/user/ps-lab/logs
2026-09-03T06:19:30+0000 [WARN] 点検完了: 警告 2 件
```

終了コードは `1` です。**「確認できなかった」を `OK` にしない**という設計なので、Windows以外で実行すると必ず警告が残ります。これは不具合ではなく、証跡を正直に保つための挙動です。

## JSON証跡への変換（実際の結果）

```bash
python3 scripts/audit_report.py --input audit.log --output audit.json
```

```json
{
  "schema_version": 1,
  "source": "audit.log",
  "result": "WARN",
  "counts": {
    "INFO": 4,
    "OK": 4,
    "WARN": 3,
    "ERROR": 0
  }
}
```

`counts` はレベル別の件数、`result` は総合判定、`entries`（上では省略）は明細です。Python側の終了コードも `1`（WARNを含むため）でした。

**新しいPythonスクリプトは1本も作っていません。** ログの1行書式（`日時 [LEVEL] メッセージ`）を、BashとPowerShellで1文字も違わない形にそろえたためです。PowerShellの `zzz` は `+09:00` とコロン付きで返るので、`Get-OpsTimestamp` でコロンを取り除いてBashの `date '+%z'` に合わせています。

## よくある質問

**Q. WARNが出たら失敗ですか。**
いいえ。`WARN` は「人が確認する必要がある」という意味で、処理自体は最後まで走っています。処理を止めたときは `ERROR` と終了コード `2` になります。

**Q. Linuxで実行した結果は、Windowsの点検結果として使えますか。**
使えません。CPU使用率の計算方法もWindowsとLinuxで違います（[21. 要件定義](../docs/21-powershell-requirements.md)の「前提と制約」参照）。どの環境で取った証跡かを必ず記録してください。
