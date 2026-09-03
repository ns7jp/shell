# 22. PowerShell演習の基本設計

## 全体構成

```text
利用者
  ├─ Invoke-ServerAudit.ps1     -ConfigPath [-OutputPath] ── 読み取り ── OS・CPU・メモリ・ディスク・サービス・イベントログ
  ├─ Install-WebServer.ps1      -ConfigPath [-Execute]    ── 構築 ───── 役割・ページ・ファイアウォール・サービス
  ├─ Test-WebServerBuild.ps1    -ConfigPath [-OutputPath] ── 確認 ───── 構築結果 → OK/WARN判定
  ├─ New-DataBackup.ps1         -ConfigPath [-Execute]    ── 保存 ───── データ → 世代付きZIP
  └─ Invoke-LogMaintenance.ps1  -ConfigPath [-Execute]    ── 整理 ───── アプリログ → 圧縮・削除
          └─ Modules/OpsCommon/OpsCommon.psm1（ログ、検証、終了コード）
                    └─ scripts/audit_report.py ── 解析 ── ログ → JSON証跡（既存のものを再利用）
```

変更を伴うスクリプト（`Install-WebServer.ps1` / `New-DataBackup.ps1` / `Invoke-LogMaintenance.ps1`）だけが `-Execute` を受け付けます。読み取りだけのスクリプト（`Invoke-ServerAudit.ps1` / `Test-WebServerBuild.ps1`）には `-Execute` がありません。**引数を見れば、そのスクリプトが何かを変えるのかどうかが分かる**ようにしています。

## Bash版との対応表

`scripts/lib/common.sh` と `scripts/powershell/Modules/OpsCommon/OpsCommon.psm1` は、同じ役割の関数を同じ順序で持っています。片方を読めば、もう片方も読めます。

| Bash（`common.sh`） | PowerShell（`OpsCommon.psm1`） | 役割 |
|---|---|---|
| `EXIT_OK` / `EXIT_WARNING` / `EXIT_ERROR` | `$OpsExitOk` / `$OpsExitWarning` / `$OpsExitError` | 終了コードの定数 |
| `timestamp` | `Get-OpsTimestamp` | ログの日時を作る |
| `log LEVEL メッセージ` | `Write-OpsLog -Level LEVEL -Message メッセージ` | 1行ログを出す |
| `die メッセージ` | `Stop-OpsScript -Message メッセージ` | 理由を残して終了コード2で止める |
| `command -v NAME` | `Test-OpsCommand -Name NAME` | コマンドの有無を真偽値で返す |
| `require_command NAME` | `Assert-OpsCommand -Name NAME` | 無ければ止める |
| `load_config PATH` | `Import-OpsConfig -Path PATH` | 設定ファイルを読み込む |
| `: "${KEY:=既定値}"` / 必須チェック | `Get-OpsConfigValue -Config … -Key … [-Default …] [-Required]` | 設定値の取り出し |
| `require_integer_range` | `Assert-OpsIntegerRange` | 整数と範囲の確認 |
| `require_absolute_safe_path` | `Assert-OpsSafePath` | 絶対パスと危険パスの確認、区切り文字の正規化 |
| （`case` 文の拒否リスト） | `Get-OpsProtectedPath` | 指定してはいけないディレクトリの一覧を返す |
| （`id -u` が0か） | `Test-OpsAdministrator` | 管理者権限の確認 |
| `run_or_show` | `Invoke-OpsAction` | ドライランか実行かの振り分け |
| `exec > >(tee -a FILE)` | `Start-OpsLogFile -Path FILE` | ログをファイルにも書く |

スクリプト同士も1対1で対応します。

| Bash版 | PowerShell版 | 対象 |
|---|---|---|
| `server_audit.sh` | `Invoke-ServerAudit.ps1` | 日次点検 |
| `provision_web_server.sh` | `Install-WebServer.ps1` | Webサーバー構築（Nginx / IIS） |
| `build_verify.sh` | `Test-WebServerBuild.ps1` | 構築後の受け入れ試験 |
| `backup.sh` | `New-DataBackup.ps1` | バックアップ（tar.gz / ZIP） |
| `rotate_app_logs.sh` | `Invoke-LogMaintenance.ps1` | ログ保守 |
| `tests/run_tests.sh` | `tests/powershell/Run-PowerShellTests.ps1` | 自動テスト |
| `audit_report.py` | （同じものを再利用） | JSON証跡化 |

## 設定キー一覧

設定ファイルはスクリプトごとに分かれています。`Install-WebServer.ps1` と `Test-WebServerBuild.ps1` だけは、構築時と確認時で値がずれないよう**同じファイルを共有**します。

### `config/powershell/audit.psd1.example`（`Invoke-ServerAudit.ps1`）

| キー | 意味 | 既定値 | 必須 |
|---|---|---|:---:|
| `CpuWarnPercent` | CPU使用率のしきい値（1〜100） | `80` | - |
| `MemoryWarnPercent` | メモリ使用率のしきい値（1〜100） | `80` | - |
| `DiskWarnPercent` | ディスク使用率のしきい値（1〜100） | `80` | - |
| `CheckServices` | 稼働を確認するサービス名の配列 | `@()` | - |
| `LogDirectory` | 読み取り可否を確認するログ格納先（絶対パス） | なし | ○ |
| `EventLogHours` | イベントログを何時間ぶん見るか（1〜168） | `24` | - |
| `EventLogErrorThreshold` | エラー何件からWARNにするか | `1` | - |

### `config/powershell/websetup.psd1.example`（構築と受け入れ試験で共用）

| キー | 意味 | 既定値 | 必須 | 使うスクリプト |
|---|---|---|:---:|---|
| `FeatureName` | 導入・確認するWindowsの役割名 | なし | ○ | 両方 |
| `ServiceName` | 起動・確認するサービス名 | なし | ○ | 両方 |
| `WebRoot` | サンプルページを置く絶対パス | なし | ○ | 両方 |
| `SiteTitle` | サンプルページのタイトル | なし | ○ | `Install-WebServer.ps1` のみ |
| `AllowedTcpPorts` | 許可するTCPポートの配列 | `@(HttpPort)` | - | `Install-WebServer.ps1` のみ |
| `HttpPort` | HTTP応答を確認するポート（1〜65535） | `80` | - | 両方 |
| `HealthCheckPath` | 確認に使うURLのパス（`/` で始める） | `/` | - | `Test-WebServerBuild.ps1` のみ |
| `FirewallRuleName` | 作る規則名の接頭辞（実際は「名前-ポート」） | `ops-lab-http` | - | 両方 |

### `config/powershell/backup.psd1.example`（`New-DataBackup.ps1`）

| キー | 意味 | 既定値 | 必須 |
|---|---|---|:---:|
| `SourceDirectory` | 保存元（絶対パス） | なし | ○ |
| `BackupDirectory` | 保存先（絶対パス。`SourceDirectory` の中は不可） | なし | ○ |
| `RetentionDays` | 世代を残す日数（1〜3650） | `7` | - |
| `ArchivePrefix` | アーカイブ名の接頭辞（英数字・`-`・`_` のみ） | なし | ○ |

### `config/powershell/logmaintenance.psd1.example`（`Invoke-LogMaintenance.ps1`）

| キー | 意味 | 既定値 | 必須 |
|---|---|---|:---:|
| `LogDirectory` | 対象のログ格納先（直下の `*.log` のみ） | なし | ○ |
| `ArchiveDirectory` | 圧縮ファイルの保管先 | なし | ○ |
| `CompressAfterDays` | 何日前より古いログを圧縮するか（0〜3650） | `1` | - |
| `DeleteAfterDays` | 何日前より古い圧縮ファイルを削除するか（`CompressAfterDays` より大きい値） | `30` | - |

必須のキーを書き忘れると、実行したスクリプトが**項目名を示して**終了コード2で止まります（例:「`LogDirectory は必須です`」）。数値の範囲やパスの安全性も、処理を始める前に確認します。

## ログ書式をそろえた理由

両方のパックが、次の1行書式だけでログを出します。

```text
2026-01-01T09:00:00+0900 [INFO] メッセージ
```

`scripts/audit_report.py` はこの書式を正規表現で読み取ります。PowerShell側でも同じ書式を出すため、**変換スクリプトを増やさずに、WindowsのログもLinuxのログも同じJSON証跡にできます**。

PowerShellの日時書式 `zzz` は `+09:00` のようにコロンが入るため、`Get-OpsTimestamp` でコロンを取り除いてBashの `date '+%z'` に合わせています。細かい話ですが、この1文字をそろえたことが「Pythonスクリプトを作らずに済んだ」理由です。

```powershell
# OpsCommon.psm1 より
$now.ToString('yyyy-MM-ddTHH:mm:ss') + $now.ToString('zzz').Replace(':', '')
```

## 設定ファイルを .psd1 にした理由

Bash版の設定ファイルは `source` で読み込みます。これは**設定ファイルの中身をコマンドとして実行する**という意味なので、`common.sh` では読み込む前に所有者と書込権限を検査しています。

PowerShellの `Import-PowerShellDataFile` は、`.psd1` を**データとしてだけ**読みます。処理が書かれていれば、実行せずにエラーになります。

```powershell
# こう書かれた設定ファイルは、実行されずに拒否されます
@{
    CpuWarnPercent = 80
    Danger         = $(Get-ChildItem / | Out-String)   # ← ここで読み込みが失敗する
}
```

つまり、**同じ危険に対して、Bashは「検査してから読む」、PowerShellは「そもそも実行しない仕組みを使う」**という違う解き方をしています。言語が変われば安全の作り方も変わる、という具体例です。

それでも「他人が書き換えられる設定ファイルを信用しない」という考え方は共通なので、権限を確認できる環境では書込権限もあわせて確認します（テスト `PS-07`）。

## `-WhatIf` ではなく `-Execute` にした理由

PowerShellには `-WhatIf` という標準の仕組みがあり、実務のコマンドレットではこちらを使います。この演習で `-Execute` を選んだ理由は3つです。

1. **Bash版パックと手順を完全にそろえるため。** 学習者が2つのパックを行き来しても、覚える約束事が1つで済みます。
2. **既定が「変更しない」だから。** `-WhatIf` は「付けると変更しない」ですが、`-Execute` は「付けないと変更しない」です。付け忘れたときに安全側へ倒れるのは後者です。
3. **確認の待ち受けが発生しないため。** `-Confirm` を伴う設計は自動テストやCIで止まってしまいます。

この選択のために、静的解析（PSScriptAnalyzer）の `PSUseShouldProcessForStateChangingFunctions` という規則を意図的に除外しています。除外の理由は `PSScriptAnalyzerSettings.psd1` にコメントとして書いてあります。**規則を黙って外さず、理由を残すこと**も設計の一部です。

実務で `-WhatIf` を使うコマンドレットに出会ったときは、「これは `-Execute` の逆向きだ」と読み替えてください。

## Windows専用の処理をどう扱うか

`Get-Service`、`Get-CimInstance`、`Get-WinEvent`、`New-NetFirewallRule`、`Get-WindowsFeature` は、LinuxのPowerShell 7には存在しません。存在しないことを**エラーにせず、確認できなかった事実として記録**します。

```powershell
if (Test-OpsCommand -Name 'Get-Service') {
    # 確認する
}
else {
    Write-OpsLog -Level WARN -Message 'Get-Service が無いためサービス状態を確認できません(Windows以外の環境です)'
    $warnings++
}
```

これはBash版が `ufw` や `systemctl` の無い環境で行っている扱いとまったく同じです。判定は3段階に分かれます。

| 状況 | 扱い | 終了コード |
|---|---|---|
| 確認して、基準を満たした | `OK` | 0のまま |
| 確認して、基準を満たさない／そもそも確認できなかった | `WARN` | 1 |
| 入力や権限が不正で、続けると危険 | `ERROR` | 2（処理を中断） |

「確認できなかった」を `OK` にしないことが重要です。これを混ぜると、証跡が信用できなくなります。

一方、**変更を伴う処理はWindows以外では実行させません**。`Install-WebServer.ps1` に `-Execute` を付けてLinuxで実行すると、何もせずに終了コード2で止まります（テスト `PS-25`）。

## 構築処理の流れ（`Install-WebServer.ps1`）

1. 設定ファイルを読み、必須項目・数値の範囲・パスの安全性を確認する。
2. `-Execute` のときだけ、Windowsであることと管理者権限を確認する。無ければ止める。
3. 役割（IIS）の導入。すでに導入済みなら何もしない（Windows Serverの `Get-WindowsFeature` 経路でも、Windows 10/11の `Get-WindowsOptionalFeature` 経路でも状態を先に確認します）。
4. サンプルページの配置。同じ内容で上書きするため、何度実行しても同じ結果になる。
5. ファイアウォール規則。規則名で存在を確認してから作るため、二重登録しない。
6. サービスの自動起動設定と開始。すでに稼働中なら開始しない。
7. `-Execute` のときは、配置したファイルを読み直して自己確認する。

3〜6がすべて「今の状態を見てから、必要なときだけ変える」形になっています。これを**冪等（べきとう）**といいます。2回実行しても壊れないことが、自動化の前提条件です。

## 受け入れ試験の流れ（`Test-WebServerBuild.ps1`）

構築に使ったのと**同じ設定ファイル**を読み、5項目を確認します。同じファイルを使うので、「構築したときの値」と「確認するときの値」がずれません。

| 確認項目 | 使うコマンド | 確認できない場合 |
|---|---|---|
| 役割が導入されているか | `Get-WindowsFeature` / `Get-WindowsOptionalFeature` | WARN（Windows以外） |
| サービスが稼働しているか | `Get-Service` | WARN |
| 配布ファイルがあるか | `Test-Path` | WARN（未構築） |
| HTTPが応答するか | `Invoke-WebRequest` | WARN（応答なし） |
| ファイアウォールで許可されているか | `Get-NetFirewallRule` | WARN（Windows以外） |

HTTP応答の確認だけは、Windows以外でも実際に試せます。**利用者から見て動いているか**を確かめる、いちばん大事な項目だからです。

## セキュリティ設計

- `Invoke-Expression`（文字列をコマンドとして実行する仕組み）を使わない。Bash版で `eval` を使わないのと同じ理由です。
- 設定値のうち、コマンドやファイル名の一部になるもの（役割名、サービス名、規則名、アーカイブ接頭辞）は、使える文字を正規表現で制限する。
- `C:\Windows`、`C:\Program Files`、`C:\Users`、`/etc` などの重要ディレクトリ「そのもの」を拒否する。配下（`C:\inetpub\wwwroot` など）は許可する。
- `..` を含むパスを拒否する。
- 変更系の既定動作をドライランにする。
- 実行ポリシーを恒久的に変更させない。必要な場面だけ範囲を限定する（[23. 検証環境の構築](23-powershell-setup.md)参照）。
- CIの権限を `contents: read` に限定する（Bash版と共通）。

## 残るリスク

シンボリックリンク、共有フォルダー越しの操作、同時実行、処理中のファイル変更、ディスク枯渇、巨大ファイルの性能は、このパックだけでは解決しません。本番化する場合は、専用のサービスアカウント、排他制御、容量の事前確認、スナップショット、監視通知の追加が必要です。

また、この演習は**1台のWindowsサーバー**だけを対象にしています。複数台へ同じ構成を配るには、Ansible、DSC（Desired State Configuration）、Terraformなどの構成管理が必要です。その位置づけは[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)にまとめています。
