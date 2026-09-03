<#
.SYNOPSIS
    PowerShell演習案件パックの共通ライブラリです。

.DESCRIPTION
    Bash版の scripts/lib/common.sh と同じ役割を、PowerShellの書き方で実装しています。
    ログ書式・終了コード・検証の考え方をBash版とそろえてあるため、
    両方を読み比べると「言語が変わっても設計は同じ」ことを確認できます。
#>

#requires -Version 7.0

Set-StrictMode -Version Latest

# 終了コードはBash版(scripts/lib/common.sh)と同じ意味です。
# 0=正常、1=警告あり、2=実行エラー(安全側で停止)。
New-Variable -Name OpsExitOk      -Value 0 -Option ReadOnly -Scope Script -Force
New-Variable -Name OpsExitWarning -Value 1 -Option ReadOnly -Scope Script -Force
New-Variable -Name OpsExitError   -Value 2 -Option ReadOnly -Scope Script -Force

# --output で指定されたログファイル。未指定なら空文字のままです。
$script:OpsLogFilePath = ''

function Get-OpsTimestamp {
    <#
    .SYNOPSIS
        ログ1行目の日時を作ります(Bash版の timestamp 関数に相当)。
    .DESCRIPTION
        書式は 2026-01-01T09:00:00+0900 です。Bash版の date '+%Y-%m-%dT%H:%M:%S%z' と
        1文字も違わない形にそろえているため、既存の scripts/audit_report.py が
        PowerShellのログもそのままJSON証跡へ変換できます。
        .NETの 'zzz' は +09:00 とコロン付きで返るため、コロンを取り除いて合わせます。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $now = Get-Date
    return $now.ToString('yyyy-MM-ddTHH:mm:ss') + $now.ToString('zzz').Replace(':', '')
}

function Start-OpsLogFile {
    <#
    .SYNOPSIS
        以降の Write-OpsLog の出力を、画面とファイルの両方へ書きます。
    .DESCRIPTION
        Bash版は exec > >(tee -a FILE) で同じことをしています。
        PowerShellではリダイレクトを組み替えるより、書き込み先を関数側で持つほうが
        初心者にも追いやすいため、この方式にしています。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $directory = Split-Path -Path $Path -Parent
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $script:OpsLogFilePath = $Path
}

function Write-OpsLog {
    <#
    .SYNOPSIS
        「日時 [LEVEL] メッセージ」の1行を出力します(Bash版の log 関数に相当)。
    .DESCRIPTION
        ERROR だけは標準エラー出力へ書きます。正常な結果と異常を混ぜないためです。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')]
        [string]$Level,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message
    )

    # ログは必ず1行にします。PowerShellの例外メッセージは複数行になることがあり、
    # そのまま書くと scripts/audit_report.py が2行目を解析できずに終了コード2になります。
    # 「ログは出たのにJSON証跡にできない」という分かりにくい失敗を防ぐための1行です。
    $flatMessage = (($Message -replace '\r?\n', ' / ') -replace '\t', ' ').Trim()
    if ([string]::IsNullOrEmpty($flatMessage)) { $flatMessage = '(メッセージなし)' }

    $line = '{0} [{1}] {2}' -f (Get-OpsTimestamp), $Level, $flatMessage

    # ここで Write-Output を使ってはいけません。ログ行が「関数の戻り値」として
    # パイプラインに流れ込み、呼び出し側の判定を壊します(docs/24 の演習6で再現します)。
    # [Console] へ直接書けば、画面には出るのにパイプラインは汚しません。
    if ($Level -eq 'ERROR') {
        [Console]::Error.WriteLine($line)
    }
    else {
        [Console]::Out.WriteLine($line)
    }

    if ($script:OpsLogFilePath) {
        Add-Content -LiteralPath $script:OpsLogFilePath -Value $line -Encoding utf8
    }
}

function Stop-OpsScript {
    <#
    .SYNOPSIS
        理由を残して終了コード2で止めます(Bash版の die 関数に相当)。
    .DESCRIPTION
        判断できない状態のまま処理を続けない、という考え方をフェイルクローズと呼びます。
        module内の exit は呼び出し元スクリプトごと終了させるため、Bashの die と同じ挙動になります。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-OpsLog -Level ERROR -Message $Message
    exit $script:OpsExitError
}

function Test-OpsCommand {
    <#
    .SYNOPSIS
        コマンドが使えるかどうかを true/false で返します(Bash版の command -v に相当)。
    .DESCRIPTION
        Windows専用コマンドレット(Get-Service、Get-CimInstance、New-NetFirewallRule など)は
        Linux上のPowerShell 7には存在しません。存在しないことをエラーにせず、
        「この環境では確認できない」と結果に残すためにこの関数を使います。
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Assert-OpsCommand {
    <#
    .SYNOPSIS
        無いと処理を続けられないコマンドを確認します(Bash版の require_command に相当)。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not (Test-OpsCommand -Name $Name)) {
        Stop-OpsScript -Message "必要なコマンドがありません: $Name"
    }
}

function Import-OpsConfig {
    <#
    .SYNOPSIS
        .psd1形式の設定ファイルを読み込みます(Bash版の load_config に相当)。
    .DESCRIPTION
        Bashの source は設定ファイルの中身をコマンドとして実行してしまうため、
        common.sh では所有者と書込権限を検査してから読み込んでいます。
        PowerShellの Import-PowerShellDataFile はデータだけを読み、コマンドを実行しません。
        設定ファイルに処理が書かれていれば、読み込み時点で拒否されます。
        それでも「他人が書き換えられる設定ファイルを信用しない」考え方は共通なので、
        権限が確認できる環境では書込権限もあわせて確認します。
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Stop-OpsScript -Message "設定ファイルが見つかりません: $Path"
    }

    $item = Get-Item -LiteralPath $Path
    if ($item.Extension -ne '.psd1') {
        Stop-OpsScript -Message "設定ファイルは .psd1 形式にしてください: $Path"
    }

    # Linux/macOSでは -rw------- のような表記から、group/otherの書込ビットを確認します。
    # Windowsでは UnixMode が空のため、この確認は行いません(ACLの確認は演習の範囲外)。
    $unixMode = if ($item.PSObject.Properties.Name -contains 'UnixMode') { $item.UnixMode } else { $null }
    if ($unixMode -and $unixMode.Length -ge 10) {
        $groupWrite = $unixMode[5]
        $otherWrite = $unixMode[8]
        if ($groupWrite -eq 'w' -or $otherWrite -eq 'w') {
            Stop-OpsScript -Message "設定ファイルが他ユーザーから書き込み可能です: chmod go-w $Path"
        }
    }

    try {
        $config = Import-PowerShellDataFile -LiteralPath $Path -ErrorAction Stop
    }
    catch {
        Stop-OpsScript -Message "設定ファイルを読み込めません(処理が書かれていないか確認してください): $Path"
    }

    if ($config -isnot [hashtable]) {
        Stop-OpsScript -Message "設定ファイルの形式が不正です(@{ キー = 値 } 形式にしてください): $Path"
    }

    return $config
}

function Get-OpsConfigValue {
    <#
    .SYNOPSIS
        設定値を1つ取り出します。必須項目の欠落と既定値の補完を1か所にまとめます。
    .DESCRIPTION
        Bash版の [[ -n ${KEY:-} ]] || die と : "${KEY:=既定値}" をまとめたものです。
        -Required を付けた項目が無ければ、項目名を示して終了コード2で止まります。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter()]
        [AllowNull()]
        [object]$Default = $null,

        [Parameter()]
        [switch]$Required
    )

    if ($Config.ContainsKey($Key) -and $null -ne $Config[$Key] -and "$($Config[$Key])".Trim() -ne '') {
        return $Config[$Key]
    }

    if ($Required) {
        Stop-OpsScript -Message "$Key は必須です"
    }

    return $Default
}

function Assert-OpsIntegerRange {
    <#
    .SYNOPSIS
        値が整数で、指定した範囲に収まっているかを確認します(Bash版の require_integer_range に相当)。
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory)]
        [int]$Minimum,

        [Parameter(Mandatory)]
        [int]$Maximum
    )

    $text = "$Value".Trim()
    if ($text -notmatch '^[0-9]+$') {
        Stop-OpsScript -Message "$Name は整数で指定してください"
    }

    $number = [int]$text
    if ($number -lt $Minimum -or $number -gt $Maximum) {
        Stop-OpsScript -Message "$Name は $Minimum から $Maximum の範囲で指定してください"
    }

    return $number
}

function Assert-OpsSafePath {
    <#
    .SYNOPSIS
        絶対パスであり、消してはいけない場所そのものではないことを確認します。
    .DESCRIPTION
        Bash版の require_absolute_safe_path に相当します。守る対象がWindowsでは
        C:\Windows や C:\Program Files などに変わるだけで、考え方は同じです。
        「C:\inetpub\wwwroot は許可、C:\Windows そのものは拒否」のように、
        重要ディレクトリ「そのもの」だけを拒否します(Bash版が /var を拒否しつつ
        /var/www/html を許可するのと同じ形です)。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        Stop-OpsScript -Message "$Name は空でない絶対パスにしてください"
    }

    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        Stop-OpsScript -Message "$Name は絶対パスにしてください(Windowsは C:\ から、Linuxは / から始めます): $Path"
    }

    if ($Path -match '(^|[\\/])\.\.([\\/]|$)') {
        Stop-OpsScript -Message "$Name に .. は使用できません: $Path"
    }

    # 区切り文字をそのOSの形にそろえてから判定します。
    # Windowsは \ と / のどちらも区切りとして通ってしまうため、そろえずに文字列比較すると
    # 'C:\data\source/inner' が 'C:\data\source\' で始まらない扱いになり、
    # 「保存先が保存元の中にある」といった検査をすり抜けます（CIのWindowsジョブで実際に発生）。
    $normalized = $Path
    if ($IsWindows) {
        $normalized = $normalized.Replace('/', '\')
    }
    $normalized = $normalized.TrimEnd('\', '/')
    if ($normalized -eq '') {
        # "/" や "C:\" のようにドライブ・ルートそのものを指した場合です。
        Stop-OpsScript -Message "$Name にドライブやルートそのものは指定できません: $Path"
    }
    if ($normalized -match '^[A-Za-z]:$') {
        Stop-OpsScript -Message "$Name にドライブやルートそのものは指定できません: $Path"
    }

    foreach ($protected in Get-OpsProtectedPath) {
        if ($normalized.Equals($protected.TrimEnd('\', '/'), [System.StringComparison]::OrdinalIgnoreCase)) {
            Stop-OpsScript -Message "$Name に重要なシステムディレクトリそのものは指定できません: $Path"
        }
    }

    return $normalized
}

function Get-OpsProtectedPath {
    <#
    .SYNOPSIS
        「そのものを指定してはいけない」ディレクトリの一覧を返します。
    .DESCRIPTION
        Windowsの実際の場所は環境変数から取り、取れない環境(Linux上での演習やCI)でも
        判定を確認できるよう、代表的な場所を文字列としても持っています。
        Bash版は /、/etc、/var などを拒否しており、守る対象が違うだけで役割は同じです。
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    $paths = [System.Collections.Generic.List[string]]::new()

    foreach ($variable in 'SystemRoot', 'ProgramFiles', 'ProgramData', 'windir') {
        $value = [System.Environment]::GetEnvironmentVariable($variable)
        if ($value) { $paths.Add($value) }
    }

    $paths.AddRange([string[]]@(
            'C:\Windows'
            'C:\Windows\System32'
            'C:\Program Files'
            'C:\Program Files (x86)'
            'C:\ProgramData'
            'C:\Users'
            'C:\inetpub'
            '/'
            '/bin'
            '/boot'
            '/dev'
            '/etc'
            '/home'
            '/lib'
            '/proc'
            '/root'
            '/run'
            '/sbin'
            '/sys'
            '/tmp'
            '/usr'
            '/var'
        ))

    return $paths.ToArray()
}

function Test-OpsAdministrator {
    <#
    .SYNOPSIS
        管理者権限で実行しているかどうかを返します(Bash版の id -u が0かの確認に相当)。
    .DESCRIPTION
        Windowsでは「管理者として実行」しているか(Administratorsロールを持つか)を確認します。
        Linux/macOSでは実行ユーザーがrootかどうかで判断します。
        役割の導入やファイアウォール設定は、この権限がないと必ず失敗するため、
        処理を始める前に確認して、途中で中途半端に止まらないようにします。
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($IsWindows) {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    return ([System.Environment]::UserName -eq 'root')
}

function Invoke-OpsAction {
    <#
    .SYNOPSIS
        変更処理を「予定の表示」か「実行」に振り分けます(Bash版の run_or_show に相当)。
    .DESCRIPTION
        -Execute を付けたときだけ処理を実行します。付けなければ [DRY-RUN] と予定だけ表示します。
        変更しないほうを既定にしておくと、操作ミスの被害を小さくできます。
        PowerShellには同じ目的の -WhatIf という仕組みもありますが、この演習では
        Bash版パックと手順をそろえるために -Execute を使います(理由は docs/22 を参照)。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Execute,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    if ($Execute) {
        Write-OpsLog -Level INFO -Message "実行: $Description"
        & $Action
        return
    }

    $line = "[DRY-RUN] $Description"
    [Console]::Out.WriteLine($line)
    if ($script:OpsLogFilePath) {
        Add-Content -LiteralPath $script:OpsLogFilePath -Value $line -Encoding utf8
    }
}

Export-ModuleMember -Function @(
    'Get-OpsTimestamp'
    'Start-OpsLogFile'
    'Write-OpsLog'
    'Stop-OpsScript'
    'Test-OpsCommand'
    'Assert-OpsCommand'
    'Import-OpsConfig'
    'Get-OpsConfigValue'
    'Assert-OpsIntegerRange'
    'Assert-OpsSafePath'
    'Get-OpsProtectedPath'
    'Test-OpsAdministrator'
    'Invoke-OpsAction'
) -Variable @('OpsExitOk', 'OpsExitWarning', 'OpsExitError')
