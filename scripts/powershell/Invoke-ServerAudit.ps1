<#
.SYNOPSIS
    Windowsサーバーの日次点検を行い、結果をログ形式で出力します。

.DESCRIPTION
    Bash版 scripts/server_audit.sh のPowerShell版です。何も変更しない読み取り専用の処理です。
    OS情報、CPU、メモリ、ディスク、サービス、イベントログ、ログ格納先を確認し、
    しきい値を超えたものを WARN として数えます。

    出力書式は「日時 [LEVEL] メッセージ」でBash版と共通です。そのため
    scripts/audit_report.py にそのまま渡してJSON証跡へ変換できます。

.PARAMETER ConfigPath
    しきい値と点検対象を書いた .psd1 設定ファイルのパスです。

.PARAMETER OutputPath
    ログを保存するファイルのパスです。省略すると画面にだけ出力します。

.EXAMPLE
    ./Invoke-ServerAudit.ps1 -ConfigPath ..\..\config\powershell\audit.psd1.example

.EXAMPLE
    ./Invoke-ServerAudit.ps1 -ConfigPath C:\ops\audit.psd1 -OutputPath C:\ops\evidence\audit.log

.OUTPUTS
    終了コード 0=正常、1=警告あり、2=実行エラー
#>

#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [Parameter()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path $PSScriptRoot 'Modules/OpsCommon/OpsCommon.psm1') -Force

# 1. 受ける --------------------------------------------------------------
$config = Import-OpsConfig -Path $ConfigPath

# 2. 疑う ----------------------------------------------------------------
$cpuWarnPercent = Assert-OpsIntegerRange -Name 'CpuWarnPercent' `
    -Value (Get-OpsConfigValue -Config $config -Key 'CpuWarnPercent' -Default 80) -Minimum 1 -Maximum 100
$memoryWarnPercent = Assert-OpsIntegerRange -Name 'MemoryWarnPercent' `
    -Value (Get-OpsConfigValue -Config $config -Key 'MemoryWarnPercent' -Default 80) -Minimum 1 -Maximum 100
$diskWarnPercent = Assert-OpsIntegerRange -Name 'DiskWarnPercent' `
    -Value (Get-OpsConfigValue -Config $config -Key 'DiskWarnPercent' -Default 80) -Minimum 1 -Maximum 100
$eventLogHours = Assert-OpsIntegerRange -Name 'EventLogHours' `
    -Value (Get-OpsConfigValue -Config $config -Key 'EventLogHours' -Default 24) -Minimum 1 -Maximum 168
$eventLogErrorThreshold = Assert-OpsIntegerRange -Name 'EventLogErrorThreshold' `
    -Value (Get-OpsConfigValue -Config $config -Key 'EventLogErrorThreshold' -Default 1) -Minimum 1 -Maximum 100000

$logDirectory = Assert-OpsSafePath -Name 'LogDirectory' `
    -Path (Get-OpsConfigValue -Config $config -Key 'LogDirectory' -Required)

$checkServices = @(Get-OpsConfigValue -Config $config -Key 'CheckServices' -Default @())
foreach ($serviceName in $checkServices) {
    if ("$serviceName" -notmatch '^[A-Za-z0-9_.\- ]+$') {
        Stop-OpsScript -Message "CheckServices に使用できない文字があります: $serviceName"
    }
}

if ($OutputPath) {
    $null = Assert-OpsSafePath -Name 'OutputPath' -Path $OutputPath
    Start-OpsLogFile -Path $OutputPath
}

# 3. 動かす（点検は読み取りのみ） ------------------------------------------
$warnings = 0
function Write-OpsThresholdResult {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][int]$Value,
        [Parameter(Mandatory)][int]$Threshold
    )

    if ($Value -ge $Threshold) {
        Write-OpsLog -Level WARN -Message ('{0}: {1}% (しきい値: {2}%)' -f $Label, $Value, $Threshold)
        return $true
    }

    Write-OpsLog -Level OK -Message ('{0}: {1}% (しきい値: {2}%)' -f $Label, $Value, $Threshold)
    return $false
}

Write-OpsLog -Level INFO -Message 'サーバー点検を開始します'
Write-OpsLog -Level INFO -Message ("ホスト名: {0}" -f [System.Net.Dns]::GetHostName())
Write-OpsLog -Level INFO -Message ("OS: {0}" -f [System.Runtime.InteropServices.RuntimeInformation]::OSDescription.Trim())
Write-OpsLog -Level INFO -Message ("PowerShell: {0}" -f $PSVersionTable.PSVersion)

# CPU: Windowsはコマンドレットから、それ以外はLinuxのloadaverageから求めます。
$cpuPercent = $null
if (Test-OpsCommand -Name 'Get-CimInstance') {
    $processors = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
    if ($processors) {
        $cpuPercent = [int]((@($processors) | Measure-Object -Property LoadPercentage -Average).Average)
    }
}
elseif (Test-Path -LiteralPath '/proc/loadavg') {
    $loadOne = [double](((Get-Content -LiteralPath '/proc/loadavg' -Raw) -split '\s+')[0])
    $cpuPercent = [int](($loadOne / [Environment]::ProcessorCount) * 100)
}
if ($null -ne $cpuPercent) {
    if (Write-OpsThresholdResult -Label 'CPU使用率' -Value $cpuPercent -Threshold $cpuWarnPercent) { $warnings++ }
}
else {
    Write-OpsLog -Level WARN -Message 'CPU使用率を取得できません'
    $warnings++
}

# メモリ
$memoryPercent = $null
if (Test-OpsCommand -Name 'Get-CimInstance') {
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($osInfo -and $osInfo.TotalVisibleMemorySize -gt 0) {
        $memoryPercent = [int]((($osInfo.TotalVisibleMemorySize - $osInfo.FreePhysicalMemory) / $osInfo.TotalVisibleMemorySize) * 100)
    }
}
elseif (Test-Path -LiteralPath '/proc/meminfo') {
    $memoryInfo = @{}
    foreach ($line in Get-Content -LiteralPath '/proc/meminfo') {
        $parts = $line -split ':\s+'
        if ($parts.Count -eq 2) { $memoryInfo[$parts[0]] = [int64](($parts[1] -replace '[^0-9]', '')) }
    }
    if ($memoryInfo.ContainsKey('MemTotal') -and $memoryInfo.ContainsKey('MemAvailable') -and $memoryInfo['MemTotal'] -gt 0) {
        $memoryPercent = [int]((($memoryInfo['MemTotal'] - $memoryInfo['MemAvailable']) / $memoryInfo['MemTotal']) * 100)
    }
}
if ($null -ne $memoryPercent) {
    if (Write-OpsThresholdResult -Label 'メモリ使用率' -Value $memoryPercent -Threshold $memoryWarnPercent) { $warnings++ }
}
else {
    Write-OpsLog -Level WARN -Message 'メモリ使用率を取得できません'
    $warnings++
}

# ディスク: Bash版は df の文字列を切り出しますが、PowerShellはオブジェクトの
# プロパティ(Used/Free)を読むため、表示桁がずれても壊れません。
# Windowsはドライブレター(C、Dなど)を、それ以外の環境ではルート(/)だけを見ます。
# この演習の主対象はWindowsで、Linuxでの実行は動作確認用と位置づけているためです。
$targetDrives = if ($IsWindows) {
    @(Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -match '^[A-Za-z]$' })
}
else {
    @(Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -eq '/' })
}

$driveChecked = 0
foreach ($drive in $targetDrives) {
    $used = [double]($drive.Used ?? 0)
    $free = [double]($drive.Free ?? 0)
    $total = $used + $free
    if ($total -le 0) { continue }
    $driveChecked++
    $drivePercent = [int](($used / $total) * 100)
    if (Write-OpsThresholdResult -Label ("ディスク使用率 {0}" -f $drive.Name) -Value $drivePercent -Threshold $diskWarnPercent) { $warnings++ }
}
if ($driveChecked -eq 0) {
    Write-OpsLog -Level WARN -Message 'ディスク使用率を取得できるドライブがありません'
    $warnings++
}

# サービス
if ($checkServices.Count -eq 0) {
    Write-OpsLog -Level INFO -Message 'CheckServices が空のため、サービス確認は行いません'
}
elseif (Test-OpsCommand -Name 'Get-Service') {
    foreach ($serviceName in $checkServices) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            Write-OpsLog -Level OK -Message "サービス稼働: $serviceName"
        }
        else {
            Write-OpsLog -Level WARN -Message "サービス停止または確認不能: $serviceName"
            $warnings++
        }
    }
}
else {
    Write-OpsLog -Level WARN -Message 'Get-Service が無いためサービス状態を確認できません(Windows以外の環境です)'
    $warnings++
}

# イベントログ
if (Test-OpsCommand -Name 'Get-WinEvent') {
    $since = (Get-Date).AddHours(-1 * $eventLogHours)
    $errorEvents = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 2; StartTime = $since } -ErrorAction SilentlyContinue)
    if ($errorEvents.Count -ge $eventLogErrorThreshold) {
        Write-OpsLog -Level WARN -Message ("システムイベントログのエラー: 直近{0}時間で{1}件 (しきい値: {2}件)" -f $eventLogHours, $errorEvents.Count, $eventLogErrorThreshold)
        $warnings++
    }
    else {
        Write-OpsLog -Level OK -Message ("システムイベントログのエラー: 直近{0}時間で{1}件 (しきい値: {2}件)" -f $eventLogHours, $errorEvents.Count, $eventLogErrorThreshold)
    }
}
else {
    Write-OpsLog -Level WARN -Message 'Get-WinEvent が無いためイベントログを確認できません(Windows以外の環境です)'
    $warnings++
}

# ログ格納先
if (Test-Path -LiteralPath $logDirectory -PathType Container) {
    Write-OpsLog -Level OK -Message "ログディレクトリ読取可能: $logDirectory"
}
else {
    Write-OpsLog -Level WARN -Message "ログディレクトリ読取不能: $logDirectory"
    $warnings++
}

# 4. 確かめる / 5. 伝える --------------------------------------------------
if ($warnings -gt 0) {
    Write-OpsLog -Level WARN -Message "点検完了: 警告 $warnings 件"
    exit $OpsExitWarning
}

Write-OpsLog -Level OK -Message '点検完了: 警告なし'
exit $OpsExitOk
