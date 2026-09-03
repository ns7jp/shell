# PSScriptAnalyzer（PowerShell版のShellCheckにあたる静的解析ツール）の設定です。
# 除外する規則は、理由をここに書いてから除外します。理由なく黙って外しません。
@{
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # PSUseShouldProcessForStateChangingFunctions:
        #   New-/Set-/Start-/Stop- で始まる関数に -WhatIf を付けるよう促す規則です。
        #   この演習パックでは、Bash版パック(--execute)と手順をそろえるため、
        #   変更処理の可否を -Execute スイッチで明示する方式に統一しています。
        #   既定が「変更しない」である点は -WhatIf と同じで、安全性は下がりません。
        #   詳細は docs/22-powershell-design.md「-WhatIf ではなく -Execute にした理由」を参照。
        'PSUseShouldProcessForStateChangingFunctions'

        # PSUseBOMForUnicodeEncodedFile:
        #   日本語を含むファイルにBOMを付けるよう促す規則です。
        #   このパックは #requires -Version 7.0 でPowerShell 7以上を前提としており、
        #   PowerShell 7の既定文字コードはBOMなしUTF-8です。リポジトリ内の
        #   Bash・Python・Markdownともに BOMなしUTF-8 でそろえているため除外します。
        'PSUseBOMForUnicodeEncodedFile'
    )
}
