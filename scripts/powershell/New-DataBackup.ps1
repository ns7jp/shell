<#
.SYNOPSIS
    指定ディレクトリを世代付きのZIPへ保存し、保存期限を過ぎた世代を整理します。

.DESCRIPTION
    Bash版 scripts/backup.sh のPowerShell版です。
    既定はドライランで、-Execute を付けたときだけ実際に保存・削除します。

    Bash版は tar.gz、こちらはWindowsで扱いやすいZIPを作ります。形式は違いますが、
    「作った直後に中身を読み直して、壊れていないことを確かめる」考え方は同じです。

.PARAMETER ConfigPath
    保存元・保存先・保存日数を書いた .psd1 設定ファイルのパスです。

.PARAMETER Execute
    実際に保存・削除を行う場合に指定します。指定しなければドライランです。

.PARAMETER OutputPath
    ログを保存するファイルのパスです。省略すると画面にだけ出力します。

.EXAMPLE
    ./New-DataBackup.ps1 -ConfigPath C:\ops\backup.psd1

.EXAMPLE
    ./New-DataBackup.ps1 -ConfigPath C:\ops\backup.psd1 -Execute

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
$sourceDirectory = Assert-OpsSafePath -Name 'SourceDirectory' `
    -Path (Get-OpsConfigValue -Config $config -Key 'SourceDirectory' -Required)
$backupDirectory = Assert-OpsSafePath -Name 'BackupDirectory' `
    -Path (Get-OpsConfigValue -Config $config -Key 'BackupDirectory' -Required)
$retentionDays = Assert-OpsIntegerRange -Name 'RetentionDays' `
    -Value (Get-OpsConfigValue -Config $config -Key 'RetentionDays' -Default 7) -Minimum 1 -Maximum 3650
$archivePrefix = Get-OpsConfigValue -Config $config -Key 'ArchivePrefix' -Required

if ("$archivePrefix" -notmatch '^[A-Za-z0-9_\-]+$') {
    Stop-OpsScript -Message "ArchivePrefix には英数字・ハイフン・アンダースコアだけを使ってください: $archivePrefix"
}

# 保存先が保存元の中にあると、バックアップがバックアップを取り込み続けます。
$sourceWithSeparator = $sourceDirectory.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if ($backupDirectory.StartsWith($sourceWithSeparator, [System.StringComparison]::OrdinalIgnoreCase) -or
    $backupDirectory.Equals($sourceDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
    Stop-OpsScript -Message "BackupDirectory を SourceDirectory の中に置くことはできません: $backupDirectory"
}

if (-not (Test-Path -LiteralPath $sourceDirectory -PathType Container)) {
    Stop-OpsScript -Message "SourceDirectory が見つかりません: $sourceDirectory"
}

if ($OutputPath) {
    $null = Assert-OpsSafePath -Name 'OutputPath' -Path $OutputPath
    Start-OpsLogFile -Path $OutputPath
}

# 3. 動かす ---------------------------------------------------------------
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$archivePath = Join-Path $backupDirectory ("{0}_{1}.zip" -f $archivePrefix, $stamp)

Write-OpsLog -Level INFO -Message 'バックアップを開始します'
Write-OpsLog -Level INFO -Message ("保存元: {0} / 保存先: {1} / 保存日数: {2}日" -f $sourceDirectory, $backupDirectory, $retentionDays)

Invoke-OpsAction -Execute $Execute -Description "New-Item -ItemType Directory -Path $backupDirectory -Force" -Action {
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
}
Invoke-OpsAction -Execute $Execute -Description "Compress-Archive -Path $sourceDirectory -DestinationPath $archivePath" -Action {
    Compress-Archive -Path $sourceDirectory -DestinationPath $archivePath -CompressionLevel Optimal -Force
}

# 4. 確かめる -------------------------------------------------------------
if ($Execute) {
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        Stop-OpsScript -Message "アーカイブを作成できませんでした: $archivePath"
    }

    # 「ファイルができた」だけでは不十分です。実際に開いて中身を数えます。
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
        $entryCount = $zip.Entries.Count
        $zip.Dispose()
    }
    catch {
        Stop-OpsScript -Message "アーカイブを読み込めません(壊れている可能性があります): $archivePath"
    }

    if ($entryCount -le 0) {
        Stop-OpsScript -Message "アーカイブが空です: $archivePath"
    }
    Write-OpsLog -Level OK -Message ("アーカイブを作成し、{0}件の項目を確認しました: {1}" -f $entryCount, $archivePath)
}

# 保存期限を過ぎた世代の整理。対象は自分が作った名前の形だけに限定します。
$expiredBefore = (Get-Date).AddDays(-1 * $retentionDays)
$expired = @()
if (Test-Path -LiteralPath $backupDirectory -PathType Container) {
    $expired = @(Get-ChildItem -LiteralPath $backupDirectory -File -Filter "$archivePrefix`_*.zip" |
            Where-Object { $_.LastWriteTime -lt $expiredBefore })
}
Write-OpsLog -Level INFO -Message ("保存期限を過ぎた世代: {0}件" -f $expired.Count)
foreach ($item in $expired) {
    Invoke-OpsAction -Execute $Execute -Description "Remove-Item -LiteralPath $($item.FullName)" -Action {
        Remove-Item -LiteralPath $item.FullName -Force
    }
}

# 5. 伝える ---------------------------------------------------------------
if (-not $Execute) {
    Write-OpsLog -Level INFO -Message 'ドライラン完了。内容を確認後、検証環境で -Execute を指定してください'
}
Write-OpsLog -Level OK -Message 'バックアップ処理を終了します'
exit $OpsExitOk
