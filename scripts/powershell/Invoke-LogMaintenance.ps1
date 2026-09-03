<#
.SYNOPSIS
    アプリのログを圧縮して保管し、保存期限を過ぎた圧縮ログを削除します。

.DESCRIPTION
    Bash版 scripts/rotate_app_logs.sh のPowerShell版です。
    既定はドライランで、-Execute を付けたときだけ実際に圧縮・削除します。

    圧縮に成功したことを確認してから元のログを空にします(先に消しません)。
    削除対象も自分が作った名前の形に限定し、関係ないファイルを消しません。

.PARAMETER ConfigPath
    ログ格納先・保管先・日数を書いた .psd1 設定ファイルのパスです。

.PARAMETER Execute
    実際に圧縮・削除を行う場合に指定します。指定しなければドライランです。

.PARAMETER OutputPath
    ログを保存するファイルのパスです。省略すると画面にだけ出力します。

.EXAMPLE
    ./Invoke-LogMaintenance.ps1 -ConfigPath C:\ops\logmaintenance.psd1

.OUTPUTS
    終了コード 0=正常、1=警告あり、2=実行エラー
#>

#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [Parameter()]
    [switch]$Execute,

    [Parameter()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path $PSScriptRoot 'Modules/OpsCommon/OpsCommon.psm1') -Force

# 1. 受ける --------------------------------------------------------------
$config = Import-OpsConfig -Path $ConfigPath

# 2. 疑う ----------------------------------------------------------------
$logDirectory = Assert-OpsSafePath -Name 'LogDirectory' `
    -Path (Get-OpsConfigValue -Config $config -Key 'LogDirectory' -Required)
$archiveDirectory = Assert-OpsSafePath -Name 'ArchiveDirectory' `
    -Path (Get-OpsConfigValue -Config $config -Key 'ArchiveDirectory' -Required)
$compressAfterDays = Assert-OpsIntegerRange -Name 'CompressAfterDays' `
    -Value (Get-OpsConfigValue -Config $config -Key 'CompressAfterDays' -Default 1) -Minimum 0 -Maximum 3650
$deleteAfterDays = Assert-OpsIntegerRange -Name 'DeleteAfterDays' `
    -Value (Get-OpsConfigValue -Config $config -Key 'DeleteAfterDays' -Default 30) -Minimum 1 -Maximum 3650

if ($compressAfterDays -ge $deleteAfterDays) {
    Stop-OpsScript -Message 'DeleteAfterDays は CompressAfterDays より大きい値にしてください'
}

if (-not (Test-Path -LiteralPath $logDirectory -PathType Container)) {
    Stop-OpsScript -Message "LogDirectory が見つかりません: $logDirectory"
}

if ($OutputPath) {
    $null = Assert-OpsSafePath -Name 'OutputPath' -Path $OutputPath
    Start-OpsLogFile -Path $OutputPath
}

# 3. 動かす ---------------------------------------------------------------
Write-OpsLog -Level INFO -Message 'ログ保守を開始します'
Write-OpsLog -Level INFO -Message ("対象: {0} / 保管先: {1} / 圧縮: {2}日以上前 / 削除: {3}日以上前" -f $logDirectory, $archiveDirectory, $compressAfterDays, $deleteAfterDays)

Invoke-OpsAction -Execute $Execute -Description "New-Item -ItemType Directory -Path $archiveDirectory -Force" -Action {
    New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null
}

# 対象は直下の *.log だけです。サブディレクトリまでは辿りません。
$compressBefore = (Get-Date).AddDays(-1 * $compressAfterDays)
$targets = @(Get-ChildItem -LiteralPath $logDirectory -File -Filter '*.log' |
        Where-Object { $_.LastWriteTime -lt $compressBefore -and $_.Length -gt 0 })
Write-OpsLog -Level INFO -Message ("圧縮対象: {0}件" -f $targets.Count)

foreach ($logFile in $targets) {
    $stamp = $logFile.LastWriteTime.ToString('yyyyMMdd-HHmmss')
    $archivePath = Join-Path $archiveDirectory ("{0}.{1}.zip" -f $logFile.Name, $stamp)

    Invoke-OpsAction -Execute $Execute -Description "Compress-Archive -Path $($logFile.FullName) -DestinationPath $archivePath" -Action {
        Compress-Archive -Path $logFile.FullName -DestinationPath $archivePath -CompressionLevel Optimal -Force
    }

    if (-not $Execute) { continue }

    # 圧縮できたことを確認してから元のログを空にします。順序を逆にすると、
    # 圧縮に失敗したときにログだけが消えます。
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf) -or (Get-Item -LiteralPath $archivePath).Length -le 0) {
        Stop-OpsScript -Message "圧縮に失敗したため元ログを残します: $($logFile.FullName)"
    }
    Clear-Content -LiteralPath $logFile.FullName
    Write-OpsLog -Level OK -Message ("圧縮して元ログを空にしました: {0} -> {1}" -f $logFile.FullName, $archivePath)
}

# 保存期限を過ぎた圧縮ログの削除。対象は自分が作った *.log.<日時>.zip だけです。
$deleteBefore = (Get-Date).AddDays(-1 * $deleteAfterDays)
$expired = @()
if (Test-Path -LiteralPath $archiveDirectory -PathType Container) {
    $expired = @(Get-ChildItem -LiteralPath $archiveDirectory -File -Filter '*.log.*.zip' |
            Where-Object { $_.LastWriteTime -lt $deleteBefore })
}
Write-OpsLog -Level INFO -Message ("削除対象: {0}件" -f $expired.Count)
foreach ($item in $expired) {
    Invoke-OpsAction -Execute $Execute -Description "Remove-Item -LiteralPath $($item.FullName)" -Action {
        Remove-Item -LiteralPath $item.FullName -Force
    }
}

# 4. 伝える ---------------------------------------------------------------
if (-not $Execute) {
    Write-OpsLog -Level INFO -Message 'ドライラン完了。内容を確認後、検証環境で -Execute を指定してください'
}
Write-OpsLog -Level OK -Message 'ログ保守を終了します'
exit $OpsExitOk
