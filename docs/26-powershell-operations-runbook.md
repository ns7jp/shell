# 26. PowerShell運用・障害対応手順

Bash版の[06. 運用・障害対応手順](06-operations-runbook.md)のWindows版です。**手順の骨格は同じで、使うコマンドだけが変わります。**

## 日次点検

```powershell
Set-Location C:\path\to\shell
git rev-parse --short HEAD

$evidence = "C:\ops-lab\evidence\audit-$(Get-Date -Format 'yyyy-MM-dd').log"
pwsh -NoProfile -File .\scripts\powershell\Invoke-ServerAudit.ps1 -ConfigPath C:\ops-lab\audit.psd1 -OutputPath $evidence
$auditStatus = $LASTEXITCODE
Write-Output "status=$auditStatus"
```

- `0`: ログを保存して完了。
- `1`: WARN行を抽出し、次の切り分けへ進む。
- `2`: 設定・権限・実行環境を確認。解決しなければ**何も変更せずに**エスカレーション。

WARN行だけを取り出すには次のようにします。

```powershell
Select-String -Path $evidence -Pattern '\[WARN\]'
```

## 初動の原則

Bash版とまったく同じ6段階です。**慌てて直さない**ことがいちばん大事です。

1. **検知:** 何が、いつ、どのホストで起きたか記録する。
2. **影響確認:** 利用者影響、対象範囲、継続中かを確認する。
3. **保全:** ログや現在の状態を保存する。慌てて削除・再起動しない。
4. **切り分け:** CPU、メモリ、ディスク、サービス、イベントログ、直近の変更の順に確認する。
5. **連絡:** 判断権限を超える操作の前に承認者へ報告する。
6. **復旧確認:** コマンドの成功だけでなく、利用者から見た動作を確認する。

## 症状別チェック

### ディスク警告

```powershell
Get-PSDrive -PSProvider FileSystem | Select-Object Name, Used, Free
Get-ChildItem C:\ -Directory | ForEach-Object {
    [pscustomobject]@{
        Path      = $_.FullName
        SizeGB    = [math]::Round((Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
                     Measure-Object -Property Length -Sum).Sum / 1GB, 2)
    }
} | Sort-Object SizeGB -Descending | Select-Object -First 10
```

**勝手にログを削除しません。** 対象プロセス、保持要件、バックアップの有無を確認し、承認を得てから対応します。

### サービス停止

```powershell
Get-Service W3SVC | Select-Object Name, Status, StartType
Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = (Get-Date).AddMinutes(-30) } -MaxEvents 50 |
    Select-Object TimeCreated, Id, LevelDisplayName, Message
```

再起動する前に、エラー内容と直近の変更を記録します。再起動の権限や影響範囲が不明ならエスカレーションします。

> `Get-Service` に渡すのは**サービス名**（`W3SVC`）で、画面に出る**表示名**（`World Wide Web 発行サービス`）ではありません。ここで「見つかりません」となる失敗が非常に多いです。`Get-Service | Where-Object DisplayName -like '*Web*'` で対応を確認できます。

### バックアップ失敗

```powershell
Get-PSDrive -PSProvider FileSystem | Select-Object Name, Free
Test-Path C:\ops-lab\source, C:\ops-lab\backups
Get-ChildItem C:\ops-lab\backups -Filter '*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -First 3
Expand-Archive -LiteralPath C:\ops-lab\backups\example-app_20260101-090000.zip -DestinationPath C:\ops-lab\check -Force
```

**失敗したアーカイブを正常品として扱わず、既存の正常な世代を削除しません。**

### HTTPが返らない

利用者に近いところから順に確認します。

```powershell
Invoke-WebRequest -Uri http://127.0.0.1/ -TimeoutSec 5 -SkipHttpErrorCheck | Select-Object StatusCode   # サーバー自身から
Get-Service W3SVC                                                                                       # サービス
Get-NetFirewallRule -DisplayName 'ops-lab-http-80'                                                       # ファイアウォール
Test-NetConnection -ComputerName サーバー名 -Port 80                                                      # 別端末から
```

**「サーバーの中では動くが外から見えない」ときは、ほぼファイアウォールかネットワークです。** サービスを再起動する前にこの順序で切り分けます。

## やってはいけないこと

| してはいけない操作 | 理由 | 代わりにすること |
|---|---|---|
| ファイアウォールを無効化する | 「動かないから切る」が習慣になると、本番で重大事故になる | 必要なポートだけ許可規則を足す |
| 実行ポリシーを `LocalMachine` で `Unrestricted` にする | 端末全体の安全性が恒久的に下がる | 1回だけ `-ExecutionPolicy Bypass`、または `CurrentUser` で `RemoteSigned` |
| NTFS権限の継承を一括で解除する | 以後、親の権限変更が反映されなくなり設計が破綻する | 変更前に `Get-Acl` の出力を保存し、範囲を限定して承認を得る |
| 原因不明のままサービスを再起動する | 証拠が消え、再発時に何も分からない | イベントログと状態を保存してから再起動する |
| アカウントをその場で無効化・削除する | 影響範囲が読めず、業務が止まる | 検出と報告までにとどめ、承認を得て別作業として行う |

## エスカレーション文例

```text
件名: [警告/障害] ホスト名 - 現象 - 検知時刻
影響: 分かっている範囲。不明なら「調査中」と書く
検知: コマンド、監視、利用者申告のどれか
確認済み: 実行したコマンドと、そこから分かった事実
未実施: 再起動、削除など承認待ちの操作
依頼: 判断または作業の承認
証跡: ログの保存場所（例: C:\ops-lab\evidence\audit-2026-01-01.log）
```

**「未実施」を書くこと**が重要です。やっていない操作を曖昧にすると、相手は「もう試した」と誤解します。

## 構築直後の引き継ぎ

`Install-WebServer.ps1 -Execute` で構築した直後は、受け入れ試験を行ってから日次点検へ引き継ぎます。

```powershell
pwsh -NoProfile -File .\scripts\powershell\Test-WebServerBuild.ps1 -ConfigPath C:\ops-lab\websetup.psd1 -OutputPath C:\ops-lab\evidence\build-verify.log
$buildStatus = $LASTEXITCODE
pwsh -NoProfile -File .\scripts\powershell\Invoke-ServerAudit.ps1 -ConfigPath C:\ops-lab\audit.psd1 -OutputPath C:\ops-lab\evidence\audit.log
$auditStatus = $LASTEXITCODE
Write-Output "build=$buildStatus audit=$auditStatus"
```

受け入れ試験が警告なしを返してから、通常の日次点検へ引き継ぎます。

## 証跡をJSONにまとめる

```powershell
python3 .\scripts\audit_report.py --input C:\ops-lab\evidence\audit.log --output C:\ops-lab\evidence\audit.json
Get-Content C:\ops-lab\evidence\audit.json | ConvertFrom-Json | Select-Object result, counts
```

Windows側のログもLinux側のログも、**同じスクリプト・同じJSON形式**になります。監査担当が2つの形式を覚える必要がありません。

## 定期実行

タスクスケジューラへの登録（`Register-ScheduledTask`）は、実行ユーザー、権限、多重起動の防止、ログの保存先、失敗時の通知を設計してから行います。このリポジトリでは**実環境への登録を `NOT RUN`**（[25. テスト仕様](25-powershell-test-plan.md)の PS-43）としています。設計せずに登録すると、失敗しても誰も気づかない仕組みができあがります。
