# 27. PowerShell用語集・チートシート

この章は**暗記用**です。1つずつ覚えようとせず、合言葉と表の形で丸ごと覚えてください。印刷して手元に置く前提で作っています。

---

## 1. 合言葉6つ（これだけは暗記する）

| # | 合言葉 | 何のため |
|---:|---|---|
| 1 | **受ける・疑う・動かす・確かめる・伝える** | どのスクリプトも、この5段階がこの順に並んでいる |
| 2 | **GTは読むだけ、SNRは止まって確認** | コマンドの動詞を見れば危険度が分かる |
| 3 | **あるか・つかいかた・なかみ** | 困ったら `Get-Command` `Get-Help` `Get-Member` |
| 4 | **ゼロは無事、イチは要注意、ニは中止** | 終了コード 0 / 1 / 2 |
| 5 | **やってない は 無事じゃない** | 確認できなかった項目を `OK` にしない |
| 6 | **Write-Output は表示ではなく、受け渡し** | 関数の中で使うと戻り値が壊れる |

---

## 2. 5語の暗記法（3パック共通）

Bash版パックとまったく同じ5語です。**言語が変わっても順序は変わりません。**

| 段階 | 意味 | Bash版での実装 | PowerShell版での実装 |
|---|---|---|---|
| 1 受ける | 引数と設定を受け取る | `while (($#))` / `--config` | `param()` / `-ConfigPath` |
| 2 疑う | 値・権限・対象を検証する | `load_config` / `require_*` | `Import-OpsConfig` / `Assert-Ops*` |
| 3 動かす | ドライラン確認後に処理する | `run_or_show` / `--execute` | `Invoke-OpsAction` / `-Execute` |
| 4 確かめる | 成果物と状態を読み直す | `build_verify.sh` | `Test-WebServerBuild.ps1` |
| 5 伝える | ログと終了コードで結果を返す | `log` / `exit 0,1,2` | `Write-OpsLog` / `exit` |

**うけて・うたがって・うごかして・たしかめて・つたえる。** どのスクリプトを開いても、コメントに「1. 受ける」「2. 疑う」と書いてあります。

---

## 3. 動詞で危険度を見分ける（GT / SNR）

PowerShellのコマンドは数千ありますが、**最初に覚えるのは動詞5つだけ**です。動詞を見た瞬間に「読むだけか、壊しうるか」が分かります。

### GT = 読むだけ（何も変わらない）

| 動詞 | 意味 | 例 |
|---|---|---|
| `Get-` | 見る | `Get-Service`、`Get-ChildItem`、`Get-Content`、`Get-WinEvent` |
| `Test-` | 試す（真偽値を返す） | `Test-Path`、`Test-NetConnection` |

このパックの `Invoke-ServerAudit.ps1` と `Test-WebServerBuild.ps1` は、GTだけでできています。だから `-Execute` がありません。

### SNR = 変える（免許がいる）

| 動詞 | 意味 | 例 |
|---|---|---|
| `Set-` | 変える | `Set-Service`、`Set-Content` |
| `New-` | 作る | `New-Item`、`New-NetFirewallRule` |
| `Remove-` | 消す | `Remove-Item` |

（`Start-` / `Stop-` / `Install-` も同じ仲間です。）

SNRが入るスクリプトは、必ず `-Execute` と管理者権限が要る設計になっています。このパックでは `Install-WebServer.ps1` / `New-DataBackup.ps1` / `Invoke-LogMaintenance.ps1` の3本です。

> **合言葉: 「GTは読むだけ、SNRは止まって確認」**

---

## 4. Linux ⇔ Windows 対応表（印刷用1枚）

**この表がこのパック最大の成果物です。** 面接で「クロスプラットフォームで運用できます」と言うときの根拠になります。

| やりたいこと | Linux (Bash) | Windows (PowerShell 7) |
|---|---|---|
| ファイル一覧 | `ls -l` | `Get-ChildItem` |
| ファイルの中身を見る | `cat file` | `Get-Content file` |
| 文字列を探す | `grep 語 file` | `Select-String -Pattern 語 -Path file` |
| 絞り込む | `grep` / `awk` | `Where-Object { $_.列 -eq 値 }` |
| 並べ替える | `sort` | `Sort-Object -Property 列` |
| 先頭N件 | `head -n N` | `Select-Object -First N` |
| サービスが動いているか | `systemctl is-active nginx` | `Get-Service W3SVC` |
| サービスを起動・自動起動 | `systemctl enable --now nginx` | `Set-Service -StartupType Automatic` → `Start-Service` |
| サービスのログを見る | `journalctl -u nginx` | `Get-WinEvent -FilterHashtable @{LogName='System'}` |
| ディスク使用率 | `df -P` | `Get-PSDrive -PSProvider FileSystem`（本パックが使用）または `Get-CimInstance Win32_LogicalDisk` |
| メモリ使用率 | `/proc/meminfo` | `Get-CimInstance Win32_OperatingSystem` |
| プロセス確認 | `pgrep -x nginx` | `Get-Process w3wp` |
| ソフト（役割）を導入 | `apt-get install nginx` | `Install-WindowsFeature Web-Server` |
| ファイアウォールで許可 | `ufw allow 80/tcp` | `New-NetFirewallRule -LocalPort 80 -Action Allow` |
| 圧縮する | `tar -czf a.tar.gz dir` | `Compress-Archive -Path dir -DestinationPath a.zip` |
| 圧縮の中身を確かめる | `tar -tzf a.tar.gz` | `[System.IO.Compression.ZipFile]::OpenRead(...)`（本パックが使用） |
| 展開する | `tar -xzf a.tar.gz` | `Expand-Archive -LiteralPath a.zip` |
| HTTP応答を見る | `curl -o /dev/null -w '%{http_code}' URL` | `Invoke-WebRequest -Uri URL -SkipHttpErrorCheck` |
| コマンドがあるか | `command -v NAME` | `Get-Command NAME -ErrorAction SilentlyContinue` |
| 管理者か | `[ "$(id -u)" -eq 0 ]` | `Test-OpsAdministrator`（本パックの関数） |
| 定期実行 | `cron` / `systemd timer` | タスクスケジューラ（`Register-ScheduledTask`） |
| 直前の終了コード | `$?` | `$LASTEXITCODE` |
| ファイルの中身を比較 | `diff -r` | `Get-FileHash` + `Compare-Object` |

---

## 5. 終了コード

| コード | 意味 | 次にすること |
|---:|---|---|
| 0 | 正常。警告なし | 証跡を保存して終わり |
| 1 | 完了したが警告あり | WARN行を読んで切り分けへ |
| 2 | 入力・権限・環境の不備で中断 | 設定と権限を直して再実行 |

> **合言葉: 「ゼロは無事、イチは要注意、ニは中止」**

そして、いちばん大事な1行です。

> **「やってない は 無事じゃない」**

Windows専用のコマンドが無い環境では、サービスもファイアウォールも確認できません。それを `OK` にすると証跡が嘘になります。このパックは必ず `WARN`（終了コード1）として残します。

```text
2026-01-01T09:00:00+0900 [WARN] Get-Service が無いためサービス状態を確認できません(Windows以外の環境です)
```

---

## 6. 困ったら「3つのGet」

| 知りたいこと | コマンド | 例 |
|---|---|---|
| そんなコマンドあるの？ | `Get-Command` | `Get-Command *Service*` |
| どう使うの？ | `Get-Help` | `Get-Help Get-Service -Examples` |
| 返ってきたモノの中身は？ | `Get-Member` | `Get-ChildItem \| Get-Member` |

> **合言葉: 「あるか・つかいかた・なかみ」**

`Get-Help ... -Examples` を実行しても実例が出ない場合は、PowerShell 7にヘルプファイルが入っていません。最初に一度だけ次を実行します（インターネット接続が必要です）。

```powershell
Update-Help -Scope CurrentUser -ErrorAction SilentlyContinue
```

取得できない環境では、`Get-Help Test-Path -Online` でブラウザーの公式ページを開けます。

このリポジトリのスクリプトにも説明が入っています。

```powershell
Get-Help .\scripts\powershell\Install-WebServer.ps1 -Full
```

---

## 7. Bashから来た人がハマる10個

| Bashでの感覚 | PowerShellでの現実 | 正しいやり方 |
|---|---|---|
| `$?` は終了コード（0が成功） | `$?` は成功/失敗の真偽値。数値ではない | 外部プログラムの終了コードは `$LASTEXITCODE` |
| `echo` で画面に出す | `Write-Output` はパイプへ値を流す。関数の戻り値と混ざる | 本パックは `[Console]::Out.WriteLine()` に統一 |
| `Write-Host` を使えばいい | 画面にしか出ず、ファイルにもパイプにも乗らない（証跡が残らない） | 同上 |
| `set -u` で未定義変数を止める | 既定では未定義変数が黙って `$null` になる | 冒頭に `Set-StrictMode -Version Latest` |
| `set -e` でエラー時に止まる | 既定ではエラーが素通りすることがある | 冒頭に `$ErrorActionPreference = 'Stop'` |
| 配列の要素数は `${#a[@]}` | 要素が1個だと配列にならず `.Count` が取れないことがある | 必ず `@($x).Count` と書く |
| `=` で比較する | `=` は代入。`if ($x = 5)` は常に真になる | 比較は `-eq` `-ne` `-lt` `-ge` |
| `*` は何にでも一致 | `-like` では `[ ]` が文字クラスになる（`'[DRY-RUN]'` が一致しない） | 文字そのものを探すなら `.Contains()` |
| `die` は関数から抜けるだけ | 関数内の `exit` は**スクリプト全体**を終了させる | 本パックはこれを意図的に使う（`Stop-OpsScript` = Bashの `die`）。他人のコードで見たら意図を確認する |
| パス区切りは `/` だけ | Windowsは `\` と `/` のどちらも通す。文字列比較すると `C:\a\src/inner` が `C:\a\src\` で始まらない扱いになる | 比較の前にOSの形へそろえる（本パックは `Assert-OpsSafePath` が行う） |

---

## 8. 変更前に声に出す5点（DRY-RUNカード）

変更系スクリプト（`-Execute` を付ける前）に、必ず声に出して確認します。

- [ ] **1. ホストは合っているか** — `hostname` を実行して読み上げる。本番と検証の取り違えが最も多い事故。
- [ ] **2. いま自分はドライランか** — `[DRY-RUN]` の行が出ているかを**目で読む**。記憶に頼らない。
- [ ] **3. 変更対象のパスを読み上げたか** — 「`C:\ops-lab\backups` に作る」と口に出す。`C:\Windows` になっていないか。
- [ ] **4. 管理者として起動しているか** — 必要なときだけ。ドライランに管理者権限は要りません。
- [ ] **5. 証跡は残るか** — `-OutputPath` を指定したか。指定していないログは後から出せません。

作業後の5点。

- [ ] 終了コードを**次のコマンドを打つ前に**記録したか（`$LASTEXITCODE`）
- [ ] 最終行の警告件数を読んだか
- [ ] 成果物を読み直したか（ZIPを開く、ページを表示する）
- [ ] ログに実ユーザー名・実ホスト名・IPが残っていないか
- [ ] できなかったことを `NOT RUN` として台帳に書いたか

---

## 9. どこで何が動くか（環境の地図）

「実機が無いから何もできない」ではなく、「この環境では動き、この環境では `NOT RUN` です」と答えられるようにします。

| 環境 | できること | できないこと |
|---|---|---|
| Linux / macOS（`pwsh` のみ） | 設定検証、危険パス拒否、ドライラン表示、ZIPバックアップと整合性確認、ログ保守、HTTP応答確認、構文チェック、自動テスト、Python証跡化 | Windows専用コマンド全般（`Get-Service` / `Get-CimInstance` / `Get-WinEvent` / `New-NetFirewallRule` / `Get-WindowsFeature`）。`-Execute` での構築は実行前に拒否される |
| GitHub Actions ubuntu-latest | 上と同じ + PSScriptAnalyzer | 同上 |
| GitHub Actions windows-latest | 上記 + Windows専用コマンドの存在確認、サービス・イベントログの実確認 | Windows Serverの役割（`Install-WindowsFeature`）、再起動をまたぐ確認 |
| Windows 10/11 Pro | 上記 + クライアント用手順でのIIS導入、ファイアウォール規則 | Server専用の役割管理 |
| Windows Server 実機/VM | すべて + 実際のIIS構築、再起動後の自動起動確認 | 本番相当の容量・負荷・長期運用 |

---

## 10. 重要用語

| 用語 | ひとことで | このパックでの例 |
|---|---|---|
| PowerShell 7 | クロスプラットフォーム版のPowerShell | `pwsh` で起動する |
| Windows PowerShell 5.1 | Windows標準の旧版。別物 | `powershell` で起動する。このパックでは使わない |
| コマンドレット | `動詞-名詞` 形式のコマンド | `Get-Service` |
| オブジェクト | 文字列ではなく、プロパティを持つデータ | `Get-ChildItem` の `Length` |
| パイプライン | オブジェクトを次のコマンドへ渡す仕組み | `Get-ChildItem \| Where-Object ...` |
| `$_` | パイプで今流れてきた1件 | `Where-Object { $_.Length -gt 0 }` |
| モジュール | 関数をまとめた部品 | `OpsCommon.psm1` |
| `.psd1` | データだけを書く設定ファイル形式 | `audit.psd1` |
| 実行ポリシー | スクリプト実行を制限する仕組み | `RemoteSigned` |
| ドライラン | 変更せず予定だけ表示すること | `-Execute` を付けない |
| 冪等性（べきとうせい） | 何度実行しても同じ状態になる性質 | 2回目は「導入済み」と表示 |
| フェイルクローズ | 判断できないときは安全側で止める | 危険パスを終了コード2で拒否 |
| 受け入れ試験 | 構築直後に完成条件を確認する試験 | `Test-WebServerBuild.ps1` |
| 証跡 | 後から確認できる実行記録 | ログとJSON |
| IIS | WindowsのWebサーバー機能 | 役割名 `Web-Server`、サービス名 `W3SVC` |
| 役割（ロール） | Windows Serverの機能単位 | `Install-WindowsFeature Web-Server` |
| サービス名と表示名 | 別物。コマンドに渡すのはサービス名 | `W3SVC`（サービス名）/ `World Wide Web 発行サービス`（表示名） |

---

## 11. 調査コマンド集

```powershell
Get-Location                                    # 現在地
whoami                                          # 実行ユーザー
$PSVersionTable.PSVersion                       # PowerShellのバージョン
Get-ExecutionPolicy -List                       # 実行ポリシー
Get-ChildItem -Path PATH -Force                 # 隠しファイルも含めた一覧
Test-Path PATH                                  # 存在するか
Get-Item PATH | Select-Object *                 # ファイルの全プロパティ
Get-PSDrive -PSProvider FileSystem              # ドライブの使用量
Get-Service NAME | Select-Object Name, Status, StartType
Get-WinEvent -FilterHashtable @{LogName='System'; Level=2} -MaxEvents 20
Get-NetFirewallRule -DisplayName '*http*'
Invoke-WebRequest -Uri http://127.0.0.1/ -SkipHttpErrorCheck | Select-Object StatusCode
Get-FileHash PATH                               # 中身が同じか比べる材料
$LASTEXITCODE                                   # 直前の外部プログラムの終了コード
```

インターネットから取得したスクリプトが実行できないときは、ブロックの印が付いていることがあります。**中身を読んで納得してから**、そのファイルだけを解除してください。

```powershell
Unblock-File -LiteralPath .\scripts\powershell\Invoke-ServerAudit.ps1
```

まとめて解除するときも、**自分が中身を確認したリポジトリの中だけ**に対象を限定します。カレントディレクトリ全体を再帰的に解除すると、ダウンロードフォルダーなど意図しない場所まで安全策を外してしまいます。

```powershell
Get-ChildItem .\scripts\powershell -Recurse -Include *.ps1, *.psm1 | Unblock-File
```
