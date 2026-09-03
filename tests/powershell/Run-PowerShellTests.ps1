<#
.SYNOPSIS
    PowerShell演習案件パックの自動テストです。管理者権限もWindowsも必要としません。

.DESCRIPTION
    Bash版 tests/run_tests.sh と同じ考え方で作った、追加モジュール不要のテストランナーです。
    一時ディレクトリだけを使い、実サーバーには一切触れません。

    出力は「ok - 名前」「not ok - 名前」の1行1件で、最後に合計を表示します。
    1件でも失敗すると終了コード1で終わります。

    Windows専用の確認(役割・サービス・ファイアウォール)はこのテストの対象外です。
    それらは docs/25-powershell-test-plan.md で NOT RUN として管理します。

.EXAMPLE
    pwsh -NoProfile -File tests/powershell/Run-PowerShellTests.ps1
#>

#requires -Version 7.0

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptDirectory = Join-Path $repositoryRoot 'scripts/powershell'
$modulePath = Join-Path $scriptDirectory 'Modules/OpsCommon/OpsCommon.psm1'
$pwshPath = (Get-Process -Id $PID).Path

$script:PassCount = 0
$script:FailCount = 0
$script:LastOutput = ''

function Write-TestPass {
    param([Parameter(Mandatory)][string]$Name)
    [Console]::Out.WriteLine("ok - $Name")
    $script:PassCount++
}

function Write-TestFail {
    param([Parameter(Mandatory)][string]$Name, [string]$Detail = '')
    [Console]::Out.WriteLine("not ok - $Name")
    if ($Detail) { [Console]::Out.WriteLine("# $Detail") }
    if ($script:LastOutput) { [Console]::Out.WriteLine(($script:LastOutput -split "`n" | ForEach-Object { "# $_" }) -join "`n") }
    $script:FailCount++
}

function Invoke-TargetScript {
    <# 対象スクリプトを別プロセスで実行し、出力と終了コードを取り出します。 #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [string[]]$ScriptArguments = @()
    )

    $output = & $pwshPath -NoProfile -File $Path @ScriptArguments 2>&1 | Out-String
    $script:LastOutput = $output
    return $LASTEXITCODE
}

function Assert-ExitCode {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Expected,
        [Parameter(Mandatory)][string]$Path,
        [string[]]$ScriptArguments = @()
    )

    $actual = Invoke-TargetScript -Path $Path -ScriptArguments $ScriptArguments
    if ($actual -eq $Expected) { Write-TestPass -Name $Name }
    else { Write-TestFail -Name $Name -Detail "expected=$Expected actual=$actual" }
}

function Assert-OutputContains {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Needle)
    # -like は [ ] をワイルドカードとして解釈するため、'[DRY-RUN]' の判定に使えません。
    # 文字列そのものを探すときは Contains を使います。
    if ($script:LastOutput.Contains($Needle)) { Write-TestPass -Name $Name }
    else { Write-TestFail -Name $Name -Detail "needle=$Needle" }
}

function Assert-True {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][bool]$Condition, [string]$Detail = '')
    if ($Condition) { Write-TestPass -Name $Name } else { Write-TestFail -Name $Name -Detail $Detail }
}

function New-TestConfig {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Body)
    Set-Content -LiteralPath $Path -Value $Body -Encoding utf8
    return $Path
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ops-ps-tests-" + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null

try {
    $sourceDirectory = Join-Path $temporaryRoot 'source'
    $backupDirectory = Join-Path $temporaryRoot 'backups'
    $logDirectory = Join-Path $temporaryRoot 'logs'
    $archiveDirectory = Join-Path $logDirectory 'archive'
    $webRoot = Join-Path $temporaryRoot 'wwwroot'
    foreach ($directory in @($sourceDirectory, $backupDirectory, $logDirectory, $archiveDirectory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $sourceDirectory 'data.txt') -Value 'test data' -Encoding utf8

    # 危険なパスの例はOSごとに違います。判定の考え方は同じです。
    $dangerousPath = if ($IsWindows) { 'C:\Windows' } else { '/etc' }

    ## PS-01 構文 ---------------------------------------------------------
    $parseErrorTotal = 0
    foreach ($file in Get-ChildItem -Path $scriptDirectory, $PSScriptRoot -Recurse -Include '*.ps1', '*.psm1') {
        $parseErrors = $null
        $tokens = $null
        [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
        $parseErrorTotal += $parseErrors.Count
    }
    Assert-True -Name 'PS-01 全スクリプトに構文エラーがない' -Condition ($parseErrorTotal -eq 0) -Detail "errors=$parseErrorTotal"

    ## PS-02..PS-09 共通モジュール ----------------------------------------
    $moduleProbe = Join-Path $temporaryRoot 'probe.ps1'

    New-TestConfig -Path $moduleProbe -Body @"
Import-Module '$modulePath' -Force
Assert-OpsSafePath -Name 'TargetPath' -Path 'relative/path'
"@ | Out-Null
    Assert-ExitCode -Name 'PS-02 相対パスを終了コード2で拒否する' -Expected 2 -Path $moduleProbe
    Assert-OutputContains -Name 'PS-02 拒否理由に絶対パスと書かれている' -Needle '絶対パス'

    New-TestConfig -Path $moduleProbe -Body @"
Import-Module '$modulePath' -Force
Assert-OpsSafePath -Name 'TargetPath' -Path '$dangerousPath'
"@ | Out-Null
    Assert-ExitCode -Name 'PS-03 重要なシステムディレクトリを終了コード2で拒否する' -Expected 2 -Path $moduleProbe
    Assert-OutputContains -Name 'PS-03 拒否理由を説明している' -Needle '重要なシステムディレクトリ'

    New-TestConfig -Path $moduleProbe -Body @"
Import-Module '$modulePath' -Force
Assert-OpsIntegerRange -Name 'CpuWarnPercent' -Value 101 -Minimum 1 -Maximum 100
"@ | Out-Null
    Assert-ExitCode -Name 'PS-04 範囲外の数値を終了コード2で拒否する' -Expected 2 -Path $moduleProbe
    Assert-OutputContains -Name 'PS-04 拒否理由に範囲が書かれている' -Needle '1 から 100 の範囲'

    New-TestConfig -Path $moduleProbe -Body @"
Import-Module '$modulePath' -Force
Import-OpsConfig -Path '$temporaryRoot/does-not-exist.psd1'
"@ | Out-Null
    Assert-ExitCode -Name 'PS-05 存在しない設定ファイルを終了コード2で拒否する' -Expected 2 -Path $moduleProbe
    Assert-OutputContains -Name 'PS-05 拒否理由を説明している' -Needle '設定ファイルが見つかりません'

    # 設定ファイルに「処理」を書いた場合。Bashのsourceはこれを実行してしまいますが、
    # Import-PowerShellDataFile はデータ以外を読み込みません。
    $executableConfig = Join-Path $temporaryRoot 'executable.psd1'
    New-TestConfig -Path $executableConfig -Body @'
@{
    CpuWarnPercent = 80
    Danger         = $(Get-ChildItem / | Out-String)
}
'@ | Out-Null
    New-TestConfig -Path $moduleProbe -Body @"
Import-Module '$modulePath' -Force
Import-OpsConfig -Path '$executableConfig'
"@ | Out-Null
    Assert-ExitCode -Name 'PS-06 処理が書かれた設定ファイルを終了コード2で拒否する' -Expected 2 -Path $moduleProbe
    Assert-OutputContains -Name 'PS-06 拒否理由を説明している' -Needle '設定ファイルを読み込めません'

    if (-not $IsWindows -and (Get-Command chmod -ErrorAction SilentlyContinue)) {
        $worldWritableConfig = Join-Path $temporaryRoot 'world-writable.psd1'
        New-TestConfig -Path $worldWritableConfig -Body '@{ CpuWarnPercent = 80 }' | Out-Null
        & chmod 666 $worldWritableConfig
        New-TestConfig -Path $moduleProbe -Body @"
Import-Module '$modulePath' -Force
Import-OpsConfig -Path '$worldWritableConfig'
"@ | Out-Null
        Assert-ExitCode -Name 'PS-07 他ユーザーが書き込める設定ファイルを終了コード2で拒否する' -Expected 2 -Path $moduleProbe
        Assert-OutputContains -Name 'PS-07 拒否理由に chmod go-w を示す' -Needle 'chmod go-w'
    }
    else {
        Write-TestPass -Name 'PS-07 権限確認テストはこの環境では対象外(Windows)'
    }

    # ログ書式が scripts/audit_report.py の正規表現と一致することを確認します。
    New-TestConfig -Path $moduleProbe -Body @"
Import-Module '$modulePath' -Force
Write-OpsLog -Level OK -Message 'format check'
"@ | Out-Null
    Assert-ExitCode -Name 'PS-08 ログ出力が正常終了する' -Expected 0 -Path $moduleProbe
    $logLine = ($script:LastOutput -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1).Trim()
    $logPattern = '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{4} \[(INFO|OK|WARN|ERROR)\] .+$'
    Assert-True -Name 'PS-08 ログ書式がBash版・Python版と一致する' -Condition ($logLine -match $logPattern) -Detail "line=$logLine"

    # Write-OpsLog がパイプラインへ値を返さないことの回帰テストです。
    # ここが壊れると、警告の件数が実際より多く数えられます。
    New-TestConfig -Path $moduleProbe -Body @"
Import-Module '$modulePath' -Force
function Test-Helper { Write-OpsLog -Level OK -Message 'inside helper'; return `$false }
if (Test-Helper) { exit 9 }
exit 0
"@ | Out-Null
    Assert-ExitCode -Name 'PS-09 ログ出力が関数の戻り値を汚さない' -Expected 0 -Path $moduleProbe

    # 複数行のメッセージを渡しても、ログが1行に収まることを確認します。
    # ここが壊れると audit_report.py がログを解析できなくなります。
    New-TestConfig -Path $moduleProbe -Body @"
Import-Module '$modulePath' -Force
Write-OpsLog -Level WARN -Message "1行目`n2行目`tタブ"
"@ | Out-Null
    Assert-ExitCode -Name 'PS-29 複数行メッセージでも正常終了する' -Expected 0 -Path $moduleProbe
    $flatLines = @($script:LastOutput -split "`n" | Where-Object { $_.Trim() })
    Assert-True -Name 'PS-29 複数行メッセージが1行にまとめられる' `
        -Condition ($flatLines.Count -eq 1 -and $flatLines[0] -match $logPattern) -Detail "lines=$($flatLines.Count)"

    ## PS-10..PS-12 点検 ---------------------------------------------------
    $auditScript = Join-Path $scriptDirectory 'Invoke-ServerAudit.ps1'
    $auditConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'audit.psd1') -Body @"
@{
    CpuWarnPercent         = 100
    MemoryWarnPercent      = 100
    DiskWarnPercent        = 100
    CheckServices          = @()
    LogDirectory           = '$logDirectory'
    EventLogHours          = 24
    EventLogErrorThreshold = 1
}
"@
    $auditStatus = Invoke-TargetScript -Path $auditScript -ScriptArguments @('-ConfigPath', $auditConfig)
    Assert-True -Name 'PS-10 点検が正常終了または警告終了する' -Condition ($auditStatus -eq 0 -or $auditStatus -eq 1) -Detail "status=$auditStatus"
    Assert-OutputContains -Name 'PS-10 点検の開始を記録する' -Needle 'サーバー点検を開始します'

    $auditBadConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'audit-bad.psd1') -Body @"
@{ CpuWarnPercent = 101; LogDirectory = '$logDirectory' }
"@
    Assert-ExitCode -Name 'PS-11 しきい値が範囲外なら終了コード2' -Expected 2 -Path $auditScript -ScriptArguments @('-ConfigPath', $auditBadConfig)
    Assert-OutputContains -Name 'PS-11 拒否理由に範囲が書かれている' -Needle '1 から 100 の範囲'

    $auditMissingConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'audit-missing.psd1') -Body '@{ CpuWarnPercent = 80 }'
    Assert-ExitCode -Name 'PS-12 必須設定が無ければ終了コード2' -Expected 2 -Path $auditScript -ScriptArguments @('-ConfigPath', $auditMissingConfig)
    Assert-OutputContains -Name 'PS-12 拒否理由に項目名が出る' -Needle 'LogDirectory は必須です'

    ## PS-13..PS-17 バックアップ -------------------------------------------
    $backupScript = Join-Path $scriptDirectory 'New-DataBackup.ps1'
    $backupConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'backup.psd1') -Body @"
@{
    SourceDirectory = '$sourceDirectory'
    BackupDirectory = '$backupDirectory'
    RetentionDays   = 7
    ArchivePrefix   = 'test'
}
"@
    Assert-ExitCode -Name 'PS-13 バックアップのドライランが成功する' -Expected 0 -Path $backupScript -ScriptArguments @('-ConfigPath', $backupConfig)
    Assert-OutputContains -Name 'PS-13 ドライランと分かる表示が出る' -Needle '[DRY-RUN]'
    Assert-True -Name 'PS-13 ドライランはアーカイブを作らない' `
        -Condition (@(Get-ChildItem -LiteralPath $backupDirectory -File).Count -eq 0)

    Assert-ExitCode -Name 'PS-14 バックアップの実行が成功する' -Expected 0 -Path $backupScript -ScriptArguments @('-ConfigPath', $backupConfig, '-Execute')
    $archive = Get-ChildItem -LiteralPath $backupDirectory -File -Filter 'test_*.zip' | Select-Object -First 1
    Assert-True -Name 'PS-14 アーカイブが作成される' -Condition ($null -ne $archive -and $archive.Length -gt 0)
    Assert-OutputContains -Name 'PS-14 アーカイブを読み直して件数を確認している' -Needle '件の項目を確認しました'

    $backupDangerConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'backup-danger.psd1') -Body @"
@{ SourceDirectory = '$dangerousPath'; BackupDirectory = '$backupDirectory'; RetentionDays = 7; ArchivePrefix = 'test' }
"@
    Assert-ExitCode -Name 'PS-15 危険な保存元を終了コード2で拒否する' -Expected 2 -Path $backupScript -ScriptArguments @('-ConfigPath', $backupDangerConfig)
    Assert-OutputContains -Name 'PS-15 拒否理由を説明している' -Needle '重要なシステムディレクトリ'

    $backupNestedConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'backup-nested.psd1') -Body @"
@{ SourceDirectory = '$sourceDirectory'; BackupDirectory = '$sourceDirectory/inner'; RetentionDays = 7; ArchivePrefix = 'test' }
"@
    Assert-ExitCode -Name 'PS-16 保存先が保存元の中なら終了コード2' -Expected 2 -Path $backupScript -ScriptArguments @('-ConfigPath', $backupNestedConfig)
    Assert-OutputContains -Name 'PS-16 拒否理由を説明している' -Needle 'SourceDirectory の中に置くことはできません'

    $backupPrefixConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'backup-prefix.psd1') -Body @"
@{ SourceDirectory = '$sourceDirectory'; BackupDirectory = '$backupDirectory'; RetentionDays = 7; ArchivePrefix = '../evil' }
"@
    Assert-ExitCode -Name 'PS-17 接頭辞に使えない文字を終了コード2で拒否する' -Expected 2 -Path $backupScript -ScriptArguments @('-ConfigPath', $backupPrefixConfig)
    Assert-OutputContains -Name 'PS-17 拒否理由に使える文字を示す' -Needle 'ArchivePrefix には英数字'

    ## PS-18..PS-20 ログ保守 -----------------------------------------------
    $logScript = Join-Path $scriptDirectory 'Invoke-LogMaintenance.ps1'
    $practiceLog = Join-Path $logDirectory 'app.log'
    Set-Content -LiteralPath $practiceLog -Value 'practice log line' -Encoding utf8
    (Get-Item -LiteralPath $practiceLog).LastWriteTime = (Get-Date).AddDays(-5)
    $originalLength = (Get-Item -LiteralPath $practiceLog).Length

    $logConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'logmaintenance.psd1') -Body @"
@{
    LogDirectory      = '$logDirectory'
    ArchiveDirectory  = '$archiveDirectory'
    CompressAfterDays = 1
    DeleteAfterDays   = 30
}
"@
    Assert-ExitCode -Name 'PS-18 ログ保守のドライランが成功する' -Expected 0 -Path $logScript -ScriptArguments @('-ConfigPath', $logConfig)
    Assert-True -Name 'PS-18 ドライランは元ログを変更しない' `
        -Condition ((Get-Item -LiteralPath $practiceLog).Length -eq $originalLength)

    Assert-ExitCode -Name 'PS-19 ログ保守の実行が成功する' -Expected 0 -Path $logScript -ScriptArguments @('-ConfigPath', $logConfig, '-Execute')
    Assert-True -Name 'PS-19 圧縮後に元ログが0バイトになる' `
        -Condition ((Get-Item -LiteralPath $practiceLog).Length -eq 0)
    Assert-True -Name 'PS-19 圧縮ファイルが保管先に作られる' `
        -Condition (@(Get-ChildItem -LiteralPath $archiveDirectory -File -Filter '*.log.*.zip').Count -ge 1)

    $logBadConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'logmaintenance-bad.psd1') -Body @"
@{ LogDirectory = '$logDirectory'; ArchiveDirectory = '$archiveDirectory'; CompressAfterDays = 30; DeleteAfterDays = 30 }
"@
    Assert-ExitCode -Name 'PS-20 削除日数が圧縮日数以下なら終了コード2' -Expected 2 -Path $logScript -ScriptArguments @('-ConfigPath', $logBadConfig)
    Assert-OutputContains -Name 'PS-20 拒否理由を説明している' -Needle 'DeleteAfterDays'

    ## PS-21..PS-25 構築 ---------------------------------------------------
    $installScript = Join-Path $scriptDirectory 'Install-WebServer.ps1'
    $webConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'websetup.psd1') -Body @"
@{
    FeatureName      = 'Web-Server'
    ServiceName      = 'W3SVC'
    WebRoot          = '$webRoot'
    SiteTitle        = 'Test Site'
    AllowedTcpPorts  = @(3389, 80)
    HttpPort         = 80
    FirewallRuleName = 'ops-lab-http'
    HealthCheckPath  = '/'
}
"@
    $installStatus = Invoke-TargetScript -Path $installScript -ScriptArguments @('-ConfigPath', $webConfig)
    Assert-True -Name 'PS-21 構築のドライランがエラーにならない' -Condition ($installStatus -le 1) -Detail "status=$installStatus"
    Assert-OutputContains -Name 'PS-21 実行予定の内容が表示される' -Needle '[DRY-RUN]'
    Assert-True -Name 'PS-21 ドライランはファイルを作らない' `
        -Condition (-not (Test-Path -LiteralPath (Join-Path $webRoot 'index.html')))

    $webBadPortConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'websetup-badport.psd1') -Body @"
@{ FeatureName = 'Web-Server'; ServiceName = 'W3SVC'; WebRoot = '$webRoot'; SiteTitle = 'Test Site'; HttpPort = 70000 }
"@
    Assert-ExitCode -Name 'PS-22 範囲外のポートを終了コード2で拒否する' -Expected 2 -Path $installScript -ScriptArguments @('-ConfigPath', $webBadPortConfig)
    Assert-OutputContains -Name 'PS-22 拒否理由に範囲が書かれている' -Needle '1 から 65535 の範囲'

    $webMissingConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'websetup-missing.psd1') -Body @"
@{ ServiceName = 'W3SVC'; WebRoot = '$webRoot'; SiteTitle = 'Test Site' }
"@
    Assert-ExitCode -Name 'PS-23 必須設定が無ければ終了コード2' -Expected 2 -Path $installScript -ScriptArguments @('-ConfigPath', $webMissingConfig)
    Assert-OutputContains -Name 'PS-23 拒否理由に項目名が出る' -Needle 'FeatureName は必須です'

    $webDangerConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'websetup-danger.psd1') -Body @"
@{ FeatureName = 'Web-Server'; ServiceName = 'W3SVC'; WebRoot = '$dangerousPath'; SiteTitle = 'Test Site' }
"@
    Assert-ExitCode -Name 'PS-24 危険な配置先を終了コード2で拒否する' -Expected 2 -Path $installScript -ScriptArguments @('-ConfigPath', $webDangerConfig)
    Assert-OutputContains -Name 'PS-24 拒否理由を説明している' -Needle '重要なシステムディレクトリ'

    if (-not $IsWindows) {
        Assert-ExitCode -Name 'PS-25 Windows以外での -Execute を終了コード2で拒否する' -Expected 2 `
            -Path $installScript -ScriptArguments @('-ConfigPath', $webConfig, '-Execute')
        Assert-OutputContains -Name 'PS-25 拒否理由を説明している' -Needle 'Windowsでのみ実行できます'
    }
    else {
        Write-TestPass -Name 'PS-25 OS判定テストはこの環境では対象外(Windows)'
    }

    ## PS-26..PS-27 受け入れ試験 -------------------------------------------
    $verifyScript = Join-Path $scriptDirectory 'Test-WebServerBuild.ps1'
    Assert-ExitCode -Name 'PS-26 受け入れ試験が不正な設定を終了コード2で拒否する' -Expected 2 `
        -Path $verifyScript -ScriptArguments @('-ConfigPath', $webBadPortConfig)

    $verifyNeverConfig = New-TestConfig -Path (Join-Path $temporaryRoot 'verify-never.psd1') -Body @"
@{
    FeatureName      = 'No-Such-Feature'
    ServiceName      = 'NoSuchService'
    WebRoot          = '$temporaryRoot/no-such-webroot'
    HttpPort         = 1
    HealthCheckPath  = '/'
    FirewallRuleName = 'ops-lab-http'
}
"@
    Assert-ExitCode -Name 'PS-27 未構築のサーバーには警告終了する' -Expected 1 -Path $verifyScript -ScriptArguments @('-ConfigPath', $verifyNeverConfig)
    Assert-OutputContains -Name 'PS-27 配布ファイルの不足を説明している' -Needle '配布ファイルが見つかりません'

    ## PS-28 証跡化との連携 ------------------------------------------------
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        $auditLog = Join-Path $temporaryRoot 'audit.log'
        $auditJson = Join-Path $temporaryRoot 'audit.json'
        Invoke-TargetScript -Path $auditScript -ScriptArguments @('-ConfigPath', $auditConfig, '-OutputPath', $auditLog) | Out-Null
        & python3 (Join-Path $repositoryRoot 'scripts/audit_report.py') --input $auditLog --output $auditJson 2>&1 | Out-Null
        $reportStatus = $LASTEXITCODE
        Assert-True -Name 'PS-28 PowerShellのログを既存のPython証跡化スクリプトで変換できる' `
            -Condition (($reportStatus -eq 0 -or $reportStatus -eq 1) -and (Test-Path -LiteralPath $auditJson)) `
            -Detail "status=$reportStatus"
    }
    else {
        Write-TestPass -Name 'PS-28 python3が無いため証跡化テストは対象外'
    }
}
finally {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
}

[Console]::Out.WriteLine("1..$($script:PassCount + $script:FailCount)")
[Console]::Out.WriteLine("# pass=$($script:PassCount) fail=$($script:FailCount)")

if ($script:FailCount -gt 0) { exit 1 }
exit 0
