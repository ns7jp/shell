<#
.SYNOPSIS
    構築したIIS(Webサーバー)が完成条件を満たしているかを確認します。何も変更しません。

.DESCRIPTION
    Bash版 scripts/build_verify.sh のPowerShell版です。
    Install-WebServer.ps1 と同じ設定ファイルを読み、そこに書かれた「望ましい状態」に
    実際のサーバーが一致しているかを、役割・サービス・配布ファイル・HTTP応答・
    ファイアウォールの5項目で確認します。

    「コマンドが成功した」ではなく「利用者から見て動いている」を判定材料にするための試験です。

.PARAMETER ConfigPath
    Install-WebServer.ps1 と共用する .psd1 設定ファイルのパスです。

.PARAMETER OutputPath
    ログを保存するファイルのパスです。省略すると画面にだけ出力します。

.EXAMPLE
    ./Test-WebServerBuild.ps1 -ConfigPath C:\ops\websetup.psd1 -OutputPath C:\ops\evidence\build-verify.log

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
$featureName = Get-OpsConfigValue -Config $config -Key 'FeatureName' -Required
$serviceName = Get-OpsConfigValue -Config $config -Key 'ServiceName' -Required
$webRoot = Assert-OpsSafePath -Name 'WebRoot' -Path (Get-OpsConfigValue -Config $config -Key 'WebRoot' -Required)
$httpPort = Assert-OpsIntegerRange -Name 'HttpPort' `
    -Value (Get-OpsConfigValue -Config $config -Key 'HttpPort' -Default 80) -Minimum 1 -Maximum 65535
$healthCheckPath = Get-OpsConfigValue -Config $config -Key 'HealthCheckPath' -Default '/'
$firewallRuleName = Get-OpsConfigValue -Config $config -Key 'FirewallRuleName' -Default 'ops-lab-http'

if ("$healthCheckPath" -notmatch '^/') {
    Stop-OpsScript -Message 'HealthCheckPath は / から始めてください'
}

if ($OutputPath) {
    $null = Assert-OpsSafePath -Name 'OutputPath' -Path $OutputPath
    Start-OpsLogFile -Path $OutputPath
}

# 3. 動かす（確認のみ） ----------------------------------------------------
$warnings = 0
Write-OpsLog -Level INFO -Message '構築後の受け入れ試験を開始します'
Write-OpsLog -Level INFO -Message ("対象役割: {0} / サービス名: {1} / ポート: {2}" -f $featureName, $serviceName, $httpPort)

# 役割
if (Test-OpsCommand -Name 'Get-WindowsFeature') {
    $feature = Get-WindowsFeature -Name $featureName -ErrorAction SilentlyContinue
    if ($feature -and $feature.Installed) {
        Write-OpsLog -Level OK -Message "役割導入済み: $featureName"
    }
    else {
        Write-OpsLog -Level WARN -Message "役割未導入: $featureName"
        $warnings++
    }
}
elseif (Test-OpsCommand -Name 'Get-WindowsOptionalFeature') {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName 'IIS-WebServerRole' -ErrorAction SilentlyContinue
    if ($feature -and $feature.State -eq 'Enabled') {
        Write-OpsLog -Level OK -Message '役割導入済み: IIS-WebServerRole'
    }
    else {
        Write-OpsLog -Level WARN -Message '役割未導入: IIS-WebServerRole'
        $warnings++
    }
}
else {
    Write-OpsLog -Level WARN -Message '役割を確認するコマンドが無いため確認できません(Windows以外の環境です)'
    $warnings++
}

# サービス
if (Test-OpsCommand -Name 'Get-Service') {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq 'Running') {
        Write-OpsLog -Level OK -Message "サービス稼働中: $serviceName"
    }
    else {
        Write-OpsLog -Level WARN -Message "サービス停止または確認不能: $serviceName"
        $warnings++
    }
}
else {
    Write-OpsLog -Level WARN -Message 'Get-Service が無いためサービス状態を確認できません(Windows以外の環境です)'
    $warnings++
}

# 配布ファイル
$indexPath = Join-Path $webRoot 'index.html'
if ((Test-Path -LiteralPath $indexPath -PathType Leaf) -and (Get-Item -LiteralPath $indexPath).Length -gt 0) {
    Write-OpsLog -Level OK -Message "配布ファイルを確認しました: $indexPath"
}
else {
    Write-OpsLog -Level WARN -Message "配布ファイルが見つかりません: $indexPath"
    $warnings++
}

# HTTP応答。ここだけはWindows以外でも実際に試せます(利用者から見た確認)。
$uri = "http://127.0.0.1:$httpPort$healthCheckPath"
$statusCode = 0
try {
    $response = Invoke-WebRequest -Uri $uri -TimeoutSec 5 -SkipHttpErrorCheck -ErrorAction Stop
    $statusCode = [int]$response.StatusCode
}
catch {
    $statusCode = 0
}
if ($statusCode -eq 200) {
    Write-OpsLog -Level OK -Message "HTTP応答を確認しました: $uri -> $statusCode"
}
else {
    Write-OpsLog -Level WARN -Message "HTTP応答を確認できません: $uri -> $statusCode"
    $warnings++
}

# ファイアウォール
if (Test-OpsCommand -Name 'Get-NetFirewallRule') {
    $ruleName = "$firewallRuleName-$httpPort"
    if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
        Write-OpsLog -Level OK -Message "ファイアウォール許可を確認しました: $ruleName ($httpPort/tcp)"
    }
    else {
        Write-OpsLog -Level WARN -Message "ファイアウォール許可を確認できません: $ruleName ($httpPort/tcp)"
        $warnings++
    }
}
else {
    Write-OpsLog -Level WARN -Message 'Get-NetFirewallRule が無いためファイアウォール設定を確認できません(Windows以外の環境です)'
    $warnings++
}

# 4. 伝える ---------------------------------------------------------------
if ($warnings -gt 0) {
    Write-OpsLog -Level WARN -Message "受け入れ試験完了: 警告 $warnings 件"
    exit $OpsExitWarning
}

Write-OpsLog -Level OK -Message '受け入れ試験完了: 警告なし'
exit $OpsExitOk
