# 23. PowerShell演習の検証環境の構築

## まず結論：手元の環境でどこまでできるか

「Windows Serverが無いから始められない」ということはありません。環境ごとに、できる範囲が変わるだけです。**自分がどの行にいるかを最初に決めて、証跡に書いてください。**

| 手元の環境 | ドライランと自動テスト | 実際のIIS構築 | 役割・サービス・FWの確認 | 備考 |
|---|:---:|:---:|:---:|---|
| A. Windows Server 2019/2022（VM・評価版） | できる | できる | できる | この演習の本来の対象 |
| B. Windows 10/11 Pro | できる | できる（クライアント用の手順） | できる | `Get-WindowsFeature` は無く、`Enable-WindowsOptionalFeature` を使う |
| C. Windows 10/11 Home | できる | 環境により不可 | 一部 | IISが使えない場合はAかBを用意する |
| D. macOS / Linux（PowerShell 7のみ） | できる | **できない**（実行前に拒否される） | できない（WARNとして記録される） | 検証や設計の理解には十分使える |

DはCIでも使っている構成です。「Windowsが無いと何も学べない」わけではありませんが、**Dで確認できたことをWindowsで確認したことにはしない**でください。区別して記録するのがこの演習の目的の1つです。

## 推奨環境（A）の作り方

- ホスト: Windows 10/11 Pro（Hyper-V が使えるエディション）
- ゲスト: Windows Server 2022 評価版（180日）
- 割り当て: CPU 2、メモリ 4GB、ディスク 40GB 程度
- ネットワーク: **内部ネットワークまたはNAT。インターネットへ公開しない**

評価版ISOはMicrosoftの評価センターから入手します。学習用VMは外部公開せず、スナップショット（チェックポイント）を取ってから作業してください。**壊してもすぐ戻せる状態を作ること自体が、この演習でいちばん大事な準備です。**

## PowerShell 7の導入

Windowsに最初から入っているのは「Windows PowerShell 5.1」で、この演習が使う「PowerShell 7」とは別物です。両方を同時に入れておけます。

```powershell
# 管理者として起動したWindows PowerShellで実行します
winget install --id Microsoft.PowerShell --source winget
```

導入後は、`pwsh` で起動するのがPowerShell 7、`powershell` で起動するのが5.1です。バージョンを確認して証跡に残します。

```powershell
pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
```

このパックのスクリプトは冒頭に `#requires -Version 7.0` を書いてあるため、5.1で実行すると処理を始める前に止まります。**気づかないまま古い環境で動かして、原因不明の失敗に悩む事故を防ぐため**です。

Linux/macOSの場合は、Microsoftの公式手順（`.tar.gz` の展開、または各OSのパッケージ）で `pwsh` を導入します。

## 実行ポリシーの考え方

Windowsには「実行ポリシー」という、スクリプトの実行を制限する仕組みがあります。ここでつまずく人がとても多い場所です。

まず現在の設定を確認します。

```powershell
Get-ExecutionPolicy -List
```

`Restricted` などで実行できない場合、**端末全体を恒久的に緩めないでください**。範囲を絞る方法が2つあります。

```powershell
# 方法1: そのコマンド1回だけ（もっとも影響が小さい。まずこれを試す）
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\powershell\Invoke-ServerAudit.ps1 -ConfigPath .\audit.psd1

# 方法2: 自分のユーザーだけ、署名なしのローカルスクリプトを許可する
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

`RemoteSigned` は「インターネットから落としたファイルには署名を求め、自分で書いたローカルのファイルは許可する」という設定です。`Unrestricted` や `Bypass` を `LocalMachine` に対して設定するのは避けます。

> インターネットからダウンロードしたスクリプトは「ブロック」の印が付くことがあります。中身を読んで納得してから `Unblock-File` で解除してください。読まずに解除しないこと。

## リポジトリの取得と最初の確認

```powershell
git clone https://github.com/ns7jp/shell.git
cd shell
pwsh -NoProfile -File tests/powershell/Run-PowerShellTests.ps1
```

最後に `# pass=62 fail=0` のように、**`fail=0` と表示されれば**環境は準備できています。合格件数はテストを追加すれば増えますし、Windowsでは対象外の確認が2件あるぶん少なくなります（[25. テスト仕様](25-powershell-test-plan.md)参照）。見るべきは件数ではなく `fail=0` です。追加モジュールのインストールは必要ありません。

`make` が使える環境なら、次でも同じことができます。

```bash
make ps-syntax   # 構文だけ確認
make ps-test     # 構文 + 自動テスト
make check-all   # Bash・Python・PowerShellをまとめて実行
```

## 安全な練習データを作る

本物の `C:\inetpub` や `C:\ProgramData` の代わりに、練習専用のフォルダーを使います。

```powershell
New-Item -ItemType Directory -Path C:\ops-lab\source, C:\ops-lab\backups, C:\ops-lab\applogs\archive, C:\ops-lab\logs -Force
Set-Content -LiteralPath C:\ops-lab\source\sample.txt -Value 'hello backup' -Encoding utf8

Copy-Item config\powershell\backup.psd1.example C:\ops-lab\backup.psd1
notepad C:\ops-lab\backup.psd1   # SourceDirectory と BackupDirectory を C:\ops-lab\... に書き換える
```

[24. ハンズオン](24-powershell-hands-on.md)では、点検用と構築用の設定ファイルも使います。同じ要領で先に用意しておくと、演習を止めずに進められます。

```powershell
Copy-Item config\powershell\audit.psd1.example    C:\ops-lab\audit.psd1
Copy-Item config\powershell\websetup.psd1.example C:\ops-lab\websetup.psd1
```

書き換えたら、**まずドライラン**です。表示されたパスが意図どおりのときだけ `-Execute` を付けます。

```powershell
pwsh -NoProfile -File scripts\powershell\New-DataBackup.ps1 -ConfigPath C:\ops-lab\backup.psd1
pwsh -NoProfile -File scripts\powershell\New-DataBackup.ps1 -ConfigPath C:\ops-lab\backup.psd1 -Execute
Get-ChildItem C:\ops-lab\backups
```

Windows以外で練習する場合は、パスを自分のホーム配下に読み替えます。

```text
SourceDirectory = '/home/ユーザー名/ps-lab/source'
BackupDirectory = '/home/ユーザー名/ps-lab/backups'
```

`C:\...` はWindows以外では絶対パスとして扱われないため、指定すると終了コード2で拒否されます。これは不具合ではなく、**そのOSで実在しない場所を黙って受け入れない**という設計です。

## ロールバック

練習用フォルダーだけを対象にしたことを、消す前に必ず確認します。

```powershell
Get-Location
Resolve-Path C:\ops-lab
Get-ChildItem C:\ops-lab -Recurse | Measure-Object   # 何件消すのかを先に数える
Remove-Item C:\ops-lab -Recurse -WhatIf              # -WhatIf で予定だけ表示（まだ消えない）
```

表示が意図どおりのときだけ `-WhatIf` を外します。リポジトリやユーザーフォルダー全体を対象にしないでください。

VMで作業している場合は、スナップショットに戻すのがいちばん確実です。

## 証跡に残すこと

環境の準備が終わったら、次を記録しておきます。あとで「どの環境の結果か」を説明できなくなるのを防ぎます。

```text
日時・タイムゾーン:
OS（エディションとビルド）:
PowerShellバージョン（$PSVersionTable.PSVersion）:
上の表のどの行の環境か（A/B/C/D）:
git commit:
実行コマンドと終了コード:
```
