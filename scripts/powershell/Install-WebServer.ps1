<#
.SYNOPSIS
    WindowsサーバーにIIS(Webサーバー)を構築します。既定は何も変更しないドライランです。

.DESCRIPTION
    Bash版 scripts/provision_web_server.sh のPowerShell版です。
    役割(IIS)の導入、サンプルページの配置、ファイアウォールの許可、サービスの自動起動設定を、
    何度実行しても同じ状態になるように(冪等に)行います。

    -Execute を付けない限り、実行予定の内容を [DRY-RUN] として表示するだけで何も変更しません。
    -Execute を付ける場合は、管理者として起動したPowerShellが必要です。

.PARAMETER ConfigPath
    構築対象を書いた .psd1 設定ファイルのパスです。Test-WebServerBuild.ps1 と共用します。

.PARAMETER Execute
    実際に変更を行う場合に指定します。指定しなければドライランです。

.PARAMETER OutputPath
    ログを保存するファイルのパスです。省略すると画面にだけ出力します。

.EXAMPLE
    ./Install-WebServer.ps1 -ConfigPath ..\..\config\powershell\websetup.psd1.example

.EXAMPLE
    ./Install-WebServer.ps1 -ConfigPath C:\ops\websetup.psd1 -Execute

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
$featureName = Get-OpsConfigValue -Config $config -Key 'FeatureName' -Required
$serviceName = Get-OpsConfigValue -Config $config -Key 'ServiceName' -Required
$siteTitle = Get-OpsConfigValue -Config $config -Key 'SiteTitle' -Required
$webRoot = Assert-OpsSafePath -Name 'WebRoot' -Path (Get-OpsConfigValue -Config $config -Key 'WebRoot' -Required)
$httpPort = Assert-OpsIntegerRange -Name 'HttpPort' `
    -Value (Get-OpsConfigValue -Config $config -Key 'HttpPort' -Default 80) -Minimum 1 -Maximum 65535
$firewallRuleName = Get-OpsConfigValue -Config $config -Key 'FirewallRuleName' -Default 'ops-lab-http'

if ("$featureName" -notmatch '^[A-Za-z0-9_.\-]+$') {
    Stop-OpsScript -Message "FeatureName に使用できない文字があります: $featureName"
}
if ("$serviceName" -notmatch '^[A-Za-z0-9_.\-]+$') {
    Stop-OpsScript -Message "ServiceName に使用できない文字があります: $serviceName"
}
if ("$firewallRuleName" -notmatch '^[A-Za-z0-9_.\- ]+$') {
    Stop-OpsScript -Message "FirewallRuleName に使用できない文字があります: $firewallRuleName"
}

$allowedTcpPorts = @(Get-OpsConfigValue -Config $config -Key 'AllowedTcpPorts' -Default @($httpPort))
$validatedPorts = foreach ($port in $allowedTcpPorts) {
    Assert-OpsIntegerRange -Name 'AllowedTcpPorts' -Value $port -Minimum 1 -Maximum 65535
}
$validatedPorts = @($validatedPorts)

if ($OutputPath) {
    $null = Assert-OpsSafePath -Name 'OutputPath' -Path $OutputPath
    Start-OpsLogFile -Path $OutputPath
}

# 変更を伴う実行だけ、事前に環境と権限を確認します(フェイルクローズ)。
if ($Execute) {
    if (-not $IsWindows) {
        Stop-OpsScript -Message 'この構築処理はWindowsでのみ実行できます。ドライラン(-Execute なし)は他のOSでも確認できます'
    }
    if (-not (Test-OpsAdministrator)) {
        Stop-OpsScript -Message '-Execute には管理者権限が必要です(PowerShellを「管理者として実行」してください)'
    }
}

# 3. 動かす ---------------------------------------------------------------
$warnings = 0
Write-OpsLog -Level INFO -Message 'Webサーバー構築を開始します'
Write-OpsLog -Level INFO -Message ("対象役割: {0} / サービス名: {1} / 許可ポート: {2}" -f $featureName, $serviceName, ($validatedPorts -join ' '))

# 役割の導入。Windows Serverは Install-WindowsFeature、Windows 10/11は
# Enable-WindowsOptionalFeature と、コマンドが分かれます。
if (Test-OpsCommand -Name 'Get-WindowsFeature') {
    $installed = Get-WindowsFeature -Name $featureName -ErrorAction SilentlyContinue
    if ($installed -and $installed.Installed) {
        Write-OpsLog -Level OK -Message "役割は導入済みです: $featureName"
    }
    else {
        Write-OpsLog -Level INFO -Message "役割は未導入です。導入します: $featureName"
        Invoke-OpsAction -Execute $Execute -Description "Install-WindowsFeature -Name $featureName -IncludeManagementTools" -Action {
            Install-WindowsFeature -Name $featureName -IncludeManagementTools | Out-Null
        }
    }
}
elseif (Test-OpsCommand -Name 'Enable-WindowsOptionalFeature') {
    Write-OpsLog -Level INFO -Message "クライアントOS向けの手順で役割を有効化します: IIS-WebServerRole"
    Invoke-OpsAction -Execute $Execute -Description 'Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart' -Action {
        Enable-WindowsOptionalFeature -Online -FeatureName 'IIS-WebServerRole' -All -NoRestart | Out-Null
    }
}
else {
    Write-OpsLog -Level WARN -Message '役割を導入するコマンドが見つからないため、IISの導入をスキップしました(Windows以外の環境です)'
    $warnings++
}

# サンプルページの配置。既にあっても同じ内容で上書きするため、何度実行しても同じ状態になります。
$indexPath = Join-Path $webRoot 'index.html'
$indexHtml = @"
<!doctype html>
<html lang="ja">
<head><meta charset="utf-8"><title>$siteTitle</title></head>
<body>
<h1>$siteTitle</h1>
<p>このページは Install-WebServer.ps1 が構築しました。</p>
</body>
</html>
"@
Write-OpsLog -Level INFO -Message "配布用サンプルページを準備しました: $indexPath"
Invoke-OpsAction -Execute $Execute -Description "Set-Content -LiteralPath $indexPath (サンプルページ)" -Action {
    if (-not (Test-Path -LiteralPath $webRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $webRoot -Force | Out-Null
    }
    Set-Content -LiteralPath $indexPath -Value $indexHtml -Encoding utf8
}

# ファイアウォール。規則名で確認してから作るため、二重登録になりません。
if (Test-OpsCommand -Name 'New-NetFirewallRule') {
    foreach ($port in $validatedPorts) {
        $ruleName = "$firewallRuleName-$port"
        $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        if ($existing) {
            Write-OpsLog -Level OK -Message "ファイアウォール規則は登録済みです: $ruleName"
            continue
        }
        Invoke-OpsAction -Execute $Execute -Description "New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow" -Action {
            New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow | Out-Null
        }
    }
}
else {
    Write-OpsLog -Level WARN -Message 'New-NetFirewallRule が見つからないためファイアウォール設定をスキップしました(Windows以外の環境です。手動確認が必要)'
    $warnings++
}

# サービスの自動起動と開始。
if (Test-OpsCommand -Name 'Get-Service') {
    Invoke-OpsAction -Execute $Execute -Description "Set-Service -Name $serviceName -StartupType Automatic; Start-Service -Name $serviceName" -Action {
        Set-Service -Name $serviceName -StartupType Automatic
        $service = Get-Service -Name $serviceName
        if ($service.Status -ne 'Running') { Start-Service -Name $serviceName }
    }
}
else {
    Write-OpsLog -Level WARN -Message 'Get-Service が見つからないためサービスの自動起動設定をスキップしました(Windows以外の環境です)'
    $warnings++
}

# 4. 確かめる -------------------------------------------------------------
if ($Execute) {
    if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
        Stop-OpsScript -Message "サンプルページを確認できません: $indexPath"
    }
    Write-OpsLog -Level OK -Message '構築直後の自己確認が完了しました'
}
else {
    Write-OpsLog -Level INFO -Message 'ドライラン完了。内容を確認後、検証環境で -Execute を指定してください'
}

# 5. 伝える ---------------------------------------------------------------
if ($warnings -gt 0) {
    Write-OpsLog -Level WARN -Message "構築完了: 警告 $warnings 件"
    exit $OpsExitWarning
}

Write-OpsLog -Level OK -Message '構築完了: 警告なし'
exit $OpsExitOk
