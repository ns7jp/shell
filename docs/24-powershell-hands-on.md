# 24. PowerShell初心者向けハンズオン

この章は[23. 検証環境の構築](23-powershell-setup.md)が終わっている前提です。演習は上から順に、**打つ → 出力を読む → わざと壊す → 直す**を繰り返します。読むだけでは覚えられません。必ず自分の環境で実行してください。

## 最初に覚える「型」

### 1. コマンドは全部「動詞-名詞」

PowerShellのコマンド（コマンドレット）は、例外なく `動詞-名詞` の形です。**英語の文として読み下せる**ので、意味が推測できます。

| コマンド | 読み下し | 意味 |
|---|---|---|
| `Get-Service` | Get（取得する）- Service（サービス）を | サービスの状態を取得する |
| `Start-Service` | Start（開始する）- Service（サービス）を | サービスを開始する |
| `Test-Path` | Test（試す）- Path（パス）を | パスが存在するか確かめる |
| `New-Item` | New（新しく作る）- Item（項目）を | ファイルやフォルダーを作る |
| `Remove-Item` | Remove（取り除く）- Item（項目）を | ファイルやフォルダーを消す |

覚える動詞は、まずこの10個だけで十分です。

| 動詞 | 意味 | この演習での例 |
|---|---|---|
| `Get` | 取得する（何も変えない） | `Get-Service`、`Get-ChildItem`、`Get-Content` |
| `Set` | 設定する（変える） | `Set-Service`、`Set-Content` |
| `New` | 新しく作る | `New-Item`、`New-NetFirewallRule` |
| `Remove` | 消す | `Remove-Item` |
| `Start` / `Stop` | 開始する / 停止する | `Start-Service` |
| `Test` | 確かめる（真偽値を返す） | `Test-Path` |
| `Import` / `Export` | 読み込む / 書き出す | `Import-PowerShellDataFile` |
| `Invoke` | 呼び出して実行する | `Invoke-WebRequest` |

**危険度は動詞で分かります。** `Get` と `Test` は読むだけなので安全、`Set`・`New`・`Remove`・`Start`・`Stop` は状態を変えます。知らないコマンドに出会ったら、まず動詞を見てください。

### 2. 困ったら「3つのGet」

PowerShellは、**PowerShell自身に聞けば答えが返ってくる**のが最大の強みです。ネット検索の前に、この3つを試す癖をつけてください。

| 知りたいこと | コマンド | 例 |
|---|---|---|
| そんなコマンドあるの？ | `Get-Command` | `Get-Command *Service*` |
| どう使うの？ | `Get-Help` | `Get-Help Get-Service -Examples` |
| 返ってきたモノの中身は？ | `Get-Member` | `Get-Service \| Get-Member` |

語呂は **「あるか（Command）・つかいかた（Help）・なかみ（Member）」** です。

このリポジトリのスクリプトにも説明が書いてあるので、同じように聞けます。

```powershell
Get-Help .\scripts\powershell\Invoke-ServerAudit.ps1 -Full
```

### 3. まず覚える6つの記号

Bash版の[04. 初心者向けハンズオン](04-hands-on.md)の6記号に対応させてあります。

| 記号 | 読み方 | 意味 | Bashでは |
|---|---|---|---|
| `$LASTEXITCODE` | 直前の終了コード | 外部プログラムの成否を数値で見る | `$?` |
| `"$name"` | 変数展開 | 二重引用符の中では変数が値になる | 同じ |
| `'そのまま'` | リテラル | 単引用符の中では変数展開されない | 同じ |
| `$( ... )` | 部分式 | 式の結果を文字列の中に埋め込む | `$( ... )` |
| `-eq` `-lt` `-ge` | 比較演算子 | `=` や `<` は使わない | `-eq` `-lt`（`[[ ]]`内） |
| `|` | パイプ | **オブジェクト**を次のコマンドへ渡す | パイプ（**文字列**を渡す） |

最後の1行が、BashとPowerShellのいちばん大きな違いです。次の演習で確かめます。

---

## 演習1: 終了コードを読む

```powershell
pwsh -NoProfile -File .\scripts\powershell\Invoke-ServerAudit.ps1 -ConfigPath .\config\powershell\audit.psd1.example
Write-Output "終了コード=$LASTEXITCODE"
```

期待: 設定例の `LogDirectory` は `C:\ProgramData\ops-lab\logs` なので、そのフォルダーが無ければ警告になり、終了コードは `1` です。Windows以外では、絶対パスとして扱えないため `2` になります。

問い: `2` が返ったとき、それは「サーバーが異常」でしょうか。違います。**設定や実行環境が正しくないので、点検を始める前に止まった**という意味です。0・1・2の意味は[21. 要件定義](21-powershell-requirements.md)の表で確認してください。

> 注意: `$LASTEXITCODE` は「外部プログラムを実行したとき」に入ります。PowerShellのコマンドレットの成否は `$?`（真偽値）です。終了コードは必ず**対象のコマンドの直後**に確認してください。

## 演習2: 3つのGetで自力で調べる

```powershell
Get-Command *-Ops*                       # このパックが用意した関数を探す
Get-Help Test-Path -Examples             # 使い方の実例を見る
Get-ChildItem . | Get-Member             # 返ってきたモノに何が入っているか見る
```

問い: `Get-Command *-Ops*` は何も返らないはずです。なぜでしょうか。`OpsCommon` モジュールをまだ読み込んでいないからです。次のように読み込むと見えます。

```powershell
Import-Module .\scripts\powershell\Modules\OpsCommon\OpsCommon.psm1 -Force
Get-Command *-Ops*
```

## 演習3: 「オブジェクト」を体感する

Bashでは `df` や `ls` の**文字列**を `awk` で切り出します。PowerShellが渡すのは**オブジェクト**なので、表示が変わっても壊れません。

```powershell
Get-ChildItem C:\ops-lab\source -File | Where-Object { $_.Length -gt 2 } | Sort-Object -Property Length -Descending | Select-Object -Property Name, Length
```

実行例（練習用に3ファイルを置いた場合）:

```text
Name  Length
----  ------
b.txt     11
a.txt      5
```

`$_` は「パイプで今流れてきた1件」を指します。`Where-Object`（絞る）→ `Sort-Object`（並べる）→ `Select-Object`（列を選ぶ）は、この順で読めば日本語の文になります。

問い: `Length` という列名はどこから来たのでしょうか。`Get-ChildItem C:\ops-lab\source | Get-Member` で確かめてください。**列名を覚える必要はなく、`Get-Member` で聞けばよい**という感覚が身につけば十分です。

このパックの `Invoke-ServerAudit.ps1` も、ディスク使用率を文字列の切り出しではなく `Used` / `Free` プロパティから計算しています。

## 演習4: しきい値を変えてWARNを出す

設定例をコピーして、ディスクのしきい値を現在値より低くします。

```powershell
Copy-Item .\config\powershell\audit.psd1.example C:\ops-lab\audit.psd1
notepad C:\ops-lab\audit.psd1     # DiskWarnPercent を 1 に、LogDirectory を C:\ops-lab\logs に変更
pwsh -NoProfile -File .\scripts\powershell\Invoke-ServerAudit.ps1 -ConfigPath C:\ops-lab\audit.psd1
Write-Output "終了コード=$LASTEXITCODE"
```

期待: `[WARN] ディスク使用率 C: ...` が出て、終了コードが `1` になります。

**しきい値を下げてわざと警告を出せる人は、しきい値の意味を理解している人です。** 面接でも説明しやすい練習です。

## 演習5: わざと失敗させる（安全機構の確認）

設定ファイルの `LogDirectory` を `C:\Windows`（Windows以外なら `/etc`）に変えて実行してください。

期待: 次のメッセージとともに終了コード `2` で止まります。

```text
2026-01-01T09:00:00+0900 [ERROR] LogDirectory に重要なシステムディレクトリそのものは指定できません: C:\Windows
```

同じように、`DiskWarnPercent = 101` にすると「`1 から 100 の範囲で指定してください`」で止まります。**エラーメッセージが「何が・なぜ・どうすれば」を含んでいるか**を確認してください。これは自分がスクリプトを書くときの目標でもあります。

## 演習6: 設定ファイルにコマンドを書いてみる

`.psd1` は「データだけ」を書く形式です。処理を書くとどうなるかを確かめます。

```powershell
@'
@{
    CpuWarnPercent = 80
    Danger         = $(Get-ChildItem C:\ | Out-String)
}
'@ | Set-Content -LiteralPath C:\ops-lab\evil.psd1 -Encoding utf8

pwsh -NoProfile -File .\scripts\powershell\Invoke-ServerAudit.ps1 -ConfigPath C:\ops-lab\evil.psd1
Write-Output "終了コード=$LASTEXITCODE"
```

期待: `設定ファイルを読み込めません(処理が書かれていないか確認してください)` で終了コード `2`。**書かれたコマンドは実行されません。**

Bashの `source` は同じことをすると**実行してしまいます**。だから `scripts/lib/common.sh` は、読み込む前に所有者と書込権限を検査しています。同じ危険に対する解き方が言語で違う、という具体例です（[22. 基本設計](22-powershell-design.md)参照）。

## 演習7: 初心者が必ず踏む罠 —— ログが戻り値に混ざる

これはこのパックを作る途中で実際に起きた不具合です。同じ形を自分で再現してください。

```powershell
@'
function Test-Bad {
    Write-Output 'しらべています'    # ← ログのつもり
    return $false                    # ← 判定のつもり
}
$result = Test-Bad
Write-Output "戻り値の個数: $(@($result).Count)"
if (Test-Bad) { Write-Output 'WARNとして数えた（本当はfalseなのに！）' } else { Write-Output '正しく数えた' }
'@ | Set-Content -LiteralPath C:\ops-lab\trap.ps1 -Encoding utf8

pwsh -NoProfile -File C:\ops-lab\trap.ps1
```

実行結果:

```text
戻り値の個数: 2
WARNとして数えた（本当はfalseなのに！）
```

**`Write-Output` は画面に出すコマンドではなく、「パイプラインへ値を流す」コマンドです。** 関数の中で使うと、その値も戻り値の一部になります。結果、`$false` を返したつもりが「2個の値」になり、`if` が真になってしまいました。実際にこの不具合で、警告が実際より多く数えられていました。

このパックでは、`Write-OpsLog` が `[Console]::Out.WriteLine()` を使うことで構造的に防いでいます。画面には出るのに、パイプラインは汚しません。回帰テスト `PS-09` がこの動作を守っています。

覚え方: **「Write-Output は表示ではなく、受け渡し」**。

## 演習8: ドライランで構築を予習する（設定のパスを直せば全環境で実行可）

```powershell
pwsh -NoProfile -File .\scripts\powershell\Install-WebServer.ps1 -ConfigPath .\config\powershell\websetup.psd1.example
Write-Output "終了コード=$LASTEXITCODE"
Test-Path C:\inetpub\wwwroot\index.html   # False のはず
```

`[DRY-RUN]` で始まる行が、**これから実行される予定のコマンド**です。パスとポートが意図どおりかを声に出して読んでから、次へ進みます。設定例は `.psd1.example` のまま指定できます（コピーは不要です）。

**Windows以外で実行する場合**は、設定例の `WebRoot = 'C:\inetpub\wwwroot'` がそのOSの絶対パスではないため、演習1と同じ理由で終了コード `2` になります。次のようにパスを書き換えたファイルを用意してください。

```bash
sed 's|C:\\inetpub\\wwwroot|'"$HOME"'/ps-lab/wwwroot|' config/powershell/websetup.psd1.example > "$HOME/ps-lab/websetup.psd1"
pwsh -NoProfile -File scripts/powershell/Install-WebServer.ps1 -ConfigPath "$HOME/ps-lab/websetup.psd1"
```

書き換えたうえでWindows以外で実行すると、役割・ファイアウォール・サービスの3項目が「Windows以外の環境です」というWARNになり、終了コードは `1` になります。これは不具合ではなく、確認できなかった事実の記録です。

```text
[WARN] 役割を導入するコマンドが見つからないため、IISの導入をスキップしました(Windows以外の環境です)
[WARN] New-NetFirewallRule が見つからないためファイアウォール設定をスキップしました(Windows以外の環境です。手動確認が必要)
[WARN] Get-Service が見つからないためサービスの自動起動設定をスキップしました(Windows以外の環境です)
```

## 演習9: 実際に構築する（Windowsのみ・使い捨て環境で）

> **本番サーバーや共有マシンでは絶対に実行しないでください。** スナップショットを取った検証用VMで行います。

```powershell
# 「管理者として実行」したPowerShell 7で
pwsh -NoProfile -File .\scripts\powershell\Install-WebServer.ps1 -ConfigPath C:\ops-lab\websetup.psd1 -Execute
Write-Output "終了コード=$LASTEXITCODE"
```

管理者権限が無い場合は、何も変更せずに次のメッセージで止まります。

```text
[ERROR] -Execute には管理者権限が必要です(PowerShellを「管理者として実行」してください)
```

Windows以外で `-Execute` を付けた場合も、実行前に拒否されます。

```text
[ERROR] この構築処理はWindowsでのみ実行できます。ドライラン(-Execute なし)は他のOSでも確認できます
```

**もう一度、同じコマンドを実行してください。** 2回目は「役割は導入済みです」「ファイアウォール規則は登録済みです」と表示され、余計な変更が起きません。これが冪等（べきとう）です。

## 演習10: 受け入れ試験とJSON証跡

```powershell
pwsh -NoProfile -File .\scripts\powershell\Test-WebServerBuild.ps1 -ConfigPath C:\ops-lab\websetup.psd1 -OutputPath C:\ops-lab\build-verify.log
$verifyStatus = $LASTEXITCODE
python3 .\scripts\audit_report.py --input C:\ops-lab\build-verify.log --output C:\ops-lab\build-verify.json
Write-Output "受け入れ試験=$verifyStatus 証跡化=$LASTEXITCODE"
Get-Content C:\ops-lab\build-verify.json | ConvertFrom-Json | Select-Object result, counts
```

ここで使っている `audit_report.py` は、**Bash版パックのために作った既存のスクリプトそのもの**です。PowerShellのログでも動くのは、ログ書式をそろえたからです。詳しくは[examples/powershell-audit-output.md](../examples/powershell-audit-output.md)を参照してください。

## 演習11: バックアップは「戻せて初めて完了」

```powershell
pwsh -NoProfile -File .\scripts\powershell\New-DataBackup.ps1 -ConfigPath C:\ops-lab\backup.psd1 -Execute

$archive = Get-ChildItem C:\ops-lab\backups -Filter '*.zip' | Sort-Object LastWriteTime | Select-Object -Last 1
New-Item -ItemType Directory -Path C:\ops-lab\restore -Force | Out-Null
Expand-Archive -LiteralPath $archive.FullName -DestinationPath C:\ops-lab\restore -Force

# 元データと復元データを、中身のハッシュ値で比べる
$before = Get-ChildItem C:\ops-lab\source -Recurse -File | Get-FileHash | Select-Object -ExpandProperty Hash | Sort-Object
$after  = Get-ChildItem C:\ops-lab\restore -Recurse -File | Get-FileHash | Select-Object -ExpandProperty Hash | Sort-Object
Compare-Object $before $after
```

期待: `Compare-Object` が何も表示しない（差が無い）こと。**「バックアップが取れた」ではなく「戻して同じだった」まで確認して、初めて完了です。**

## 覚え方：5語のならび

Bash版パックとまったく同じです。**言語が変わっても、順序は変わりません。**

**受ける・疑う・動かす・確かめる・伝える**

1. **受ける** — 引数と設定ファイルを受け取る（`param()` / `Import-OpsConfig`）
2. **疑う** — 必須・範囲・パスの安全性・権限を検証する（`Assert-Ops*`）
3. **動かす** — ドライランで確認してから `-Execute` で処理する（`Invoke-OpsAction`）
4. **確かめる** — 作った成果物を読み直す（ZIPを開く、`index.html` を読む）
5. **伝える** — ログと終了コードで結果を残す（`Write-OpsLog` / `exit`）

このパックのどのスクリプトを開いても、この5段階がこの順に並んでいます。**コメントに「1. 受ける」「2. 疑う」と書いてあるので、探してみてください。**

## つまずきポイント先回り集

| 症状 | 原因 | 対処 |
|---|---|---|
| 「このシステムではスクリプトの実行が無効」 | 実行ポリシー | `pwsh -ExecutionPolicy Bypass -File ...` で1回だけ許可（[23章](23-powershell-setup.md)） |
| 文字が化ける | Windows PowerShell 5.1で実行した | `pwsh` で起動する。`#requires -Version 7.0` で止まるはず |
| `$LASTEXITCODE` が空 | コマンドレットは終了コードを設定しない | 外部プログラムの直後に見る。コマンドレットの成否は `$?` |
| `-eq` を `=` と書いてエラー | 比較演算子が違う | `=` は代入。比較は `-eq` |
| `if ($x = 5)` が常に真 | 代入してしまっている | `if ($x -eq 5)` |
| パスに空白があると壊れる | 引用符が足りない | `"C:\Program Files\..."` と二重引用符で囲む |
| 関数の戻り値がおかしい | `Write-Output` が混ざっている | 演習7を参照 |
| `-like '[DRY-RUN]'` が一致しない | `[ ]` はワイルドカードの文字クラス | 文字列そのものを探すなら `.Contains()` |
| `C:\...` を指定したら終了コード2 | Windows以外では絶対パスではない | そのOSのパスに書き換える |
| 管理者なのに拒否される | `powershell`（5.1）を管理者起動している | `pwsh` を管理者として起動する |
| Windowsで `C:\a\b/c` のような書き方をした | Windowsは `\` と `/` の両方を区切りとして受け付ける | 混ぜない。このパックは `Assert-OpsSafePath` でOSの形にそろえてから判定する（PS-30） |

## 作業前チェック

- [ ] ホスト名・環境（A/B/C/D）・実行ユーザーは正しいか
- [ ] 対象パスと除外対象を声に出して確認したか
- [ ] スナップショットまたは復旧方法はあるか
- [ ] ドライランの `[DRY-RUN]` 表示は意図どおりか
- [ ] 影響時間と承認者は明確か

## 作業後チェック

- [ ] 終了コードを直後に記録したか
- [ ] 成果物を読み直したか（ZIPを開く、ページを表示する）
- [ ] 利用者視点でも確認したか（ブラウザーでHTTP応答を見る）
- [ ] ログに秘密情報・実IP・実ホスト名が含まれていないか
- [ ] 未実施項目を `NOT RUN` として残したか
