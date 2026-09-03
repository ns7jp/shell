# 25. PowerShell演習のテスト仕様

## テスト方針

自動テストは一時ディレクトリだけを使い、管理者権限も、Windows実機も、追加モジュールのインストールも必要としません。そのため、WindowsでもLinuxでも、GitHub Actionsでも同じテストが動きます。

Windows専用の確認（役割の導入、サービス、ファイアウォール、再起動後の自動起動）は、**自動テストの対象外**です。自動テストが通ったことをもって、Windows実機での動作を保証しません。未実施の項目は誇張せず `NOT RUN` と明記します。

終了コードの意味は3パック共通です（`OpsCommon.psm1` の定義）。

| 終了コード | 定数名 | 意味 |
|---:|---|---|
| 0 | `$OpsExitOk` | 正常終了、警告なし |
| 1 | `$OpsExitWarning` | 完了したが警告あり（確認できなかった項目を含む） |
| 2 | `$OpsExitError` | 入力・権限・環境の不備で中断（フェイルクローズ） |

## 実行方法

```bash
make ps-syntax    # 構文だけ確認
make ps-test      # 構文 + 自動テスト
make ps-lint      # PSScriptAnalyzer（要インストール）
make check-all    # Bash・Python・PowerShellをまとめて実行
```

`make` が無い環境では直接実行します。

```powershell
pwsh -NoProfile -File tests/powershell/Run-PowerShellTests.ps1
```

出力は1件1行で、最後に合計が出ます。1件でも失敗すると終了コード1で終わります。

```text
ok - PS-01 全スクリプトに構文エラーがない
...
1..58
# pass=58 fail=0
```

## 自動テストケース

`tests/powershell/Run-PowerShellTests.ps1` の各アサーションに対応します。1つのIDが複数行の `ok -` を出すことがあります（終了コードとメッセージ内容を別々に確認するため）。

| ID | 対象 | 条件 | 期待結果 | 種別 |
|---|---|---|---|---|
| PS-01 | 全スクリプト | PowerShellパーサーで解析 | 構文エラーなし | 自動 |
| PS-02 | `Assert-OpsSafePath` | 相対パス | 終了2、「絶対パス」を含む | 自動 |
| PS-03 | `Assert-OpsSafePath` | `C:\Windows`（Linuxでは `/etc`） | 終了2、「重要なシステムディレクトリ」を含む | 自動 |
| PS-04 | `Assert-OpsIntegerRange` | 範囲外の値 | 終了2、「1 から 100 の範囲」を含む | 自動 |
| PS-05 | `Import-OpsConfig` | 存在しないファイル | 終了2、「設定ファイルが見つかりません」 | 自動 |
| PS-06 | `Import-OpsConfig` | 処理が書かれた `.psd1` | 終了2、処理は実行されない | 自動 |
| PS-07 | `Import-OpsConfig` | 他ユーザーが書き込める設定ファイル | 終了2、`chmod go-w` を案内 | 自動（Windowsでは対象外） |
| PS-08 | `Write-OpsLog` | ログ1行を出力 | `audit_report.py` の正規表現に一致 | 自動 |
| PS-09 | `Write-OpsLog` | 関数の中でログを出して真偽値を返す | 戻り値が汚れない（回帰テスト） | 自動 |
| PS-29 | `Write-OpsLog` | 改行とタブを含むメッセージ | 1行にまとめられ、書式が保たれる | 自動 |
| PS-10 | 点検 | 正常な設定 | 終了0または1、開始ログを含む | 自動 |
| PS-11 | 点検 | `CpuWarnPercent = 101` | 終了2、範囲を説明 | 自動 |
| PS-12 | 点検 | `LogDirectory` 未設定 | 終了2、「LogDirectory は必須です」 | 自動 |
| PS-13 | バックアップ | 正常な設定、ドライラン | 終了0、`[DRY-RUN]` 表示、ファイル未作成 | 自動 |
| PS-14 | バックアップ | 正常な設定、`-Execute` | 終了0、読めるZIP、件数を確認 | 自動 |
| PS-15 | バックアップ | 保存元が危険なパス | 終了2、拒否理由あり | 自動 |
| PS-16 | バックアップ | 保存先が保存元の配下 | 終了2、拒否理由あり | 自動 |
| PS-17 | バックアップ | 接頭辞に `../` | 終了2、使える文字を案内 | 自動 |
| PS-18 | ログ保守 | ドライラン | 終了0、元ログのサイズが変わらない | 自動 |
| PS-19 | ログ保守 | `-Execute` | 終了0、ZIP作成、元ログ0バイト | 自動 |
| PS-20 | ログ保守 | `DeleteAfterDays <= CompressAfterDays` | 終了2、理由を説明 | 自動 |
| PS-21 | 構築 | 正常な設定、ドライラン | 終了0または1、`[DRY-RUN]` 表示、ファイル未作成 | 自動 |
| PS-22 | 構築 | `HttpPort = 70000` | 終了2、「1 から 65535 の範囲」 | 自動 |
| PS-23 | 構築 | `FeatureName` 未設定 | 終了2、「FeatureName は必須です」 | 自動 |
| PS-24 | 構築 | `WebRoot` が危険なパス | 終了2、拒否理由あり | 自動 |
| PS-25 | 構築 | Windows以外で `-Execute` | 終了2、「Windowsでのみ実行できます」 | 自動（Windowsでは対象外） |
| PS-26 | 受け入れ試験 | 不正な設定 | 終了2 | 自動 |
| PS-27 | 受け入れ試験 | 未構築のサーバー相当 | 終了1、不足項目を複数警告 | 自動 |
| PS-28 | 証跡化 | 点検ログを `audit_report.py` へ渡す | 終了0または1、JSONを作成 | 自動 |

PS-07とPS-25は、実行環境がWindowsのときはスキップし、その旨を結果に残します（黙って消しません）。

## 手動テストケース

自動化していない項目です。実行者が結果を読んで判断します。

| ID | 対象 | 条件 | 期待結果 | 種別 |
|---|---|---|---|---|
| PS-30 | 構築 | 同じ設定で2回続けて `-Execute` | 2回目に「導入済み」「登録済み」と表示され、余計な変更が出ない（冪等性） | 手動 |
| PS-31 | バックアップ | 作成したZIPを別フォルダーへ展開し、`Get-FileHash` で比較 | `Compare-Object` に差分が出ない | 手動 |
| PS-32 | 点検 | しきい値を現在値より低くする | 該当項目がWARNになり終了1 | 手動 |
| PS-33 | 全スクリプト | Windows PowerShell 5.1（`powershell`）で実行 | `#requires` により処理を始める前に停止する | 手動 |
| PS-34 | 受け入れ試験 | 構築済みサーバーに対して既存のBash側点検を実行 | ログ書式が同じで、同じ `audit_report.py` で証跡化できる | 手動 |

## NOT RUN（未実施）

環境が無いために実施できていない項目です。**推測を実績として書きません。**

| ID | 対象 | 条件 | 未実施の理由 |
|---|---|---|---|
| PS-40 | 構築 | Windows Server 実機での `-Execute` によるIIS導入 | Windows実機が必要。CIのwindows-latestは検証用であり、実運用のServer OSではない |
| PS-41 | 構築 | 再起動後のサービス自動起動とHTTP応答 | 再起動をまたぐ確認は実機VMが必要 |
| PS-42 | 構築 | ファイアウォール許可後の、別端末からのポート到達性 | 2台以上のネットワーク環境が必要 |
| PS-43 | 運用 | タスクスケジューラへ登録しての定期実行 | 登録内容と定期実行ログが必要。このパックには登録スクリプトを含めていない |
| PS-44 | 運用 | 本番相当の容量・件数での性能と所要時間 | 実データが必要 |
| PS-45 | 構成管理 | Ansible/DSC等による複数台への同一構成適用 | 未着手（[10. ロードマップ](10-server-build-roadmap.md)参照） |

## 静的解析（PSScriptAnalyzer）

Bash版の ShellCheck にあたるツールです。CIで実行します。

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path ./scripts/powershell -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```

`PSScriptAnalyzerSettings.psd1` で2つの規則を除外しています。**除外の理由は設定ファイル内にコメントで書いてあります。理由を書かずに規則を外さないでください。**

| 除外した規則 | 理由 |
|---|---|
| `PSUseShouldProcessForStateChangingFunctions` | Bash版と手順をそろえるため `-Execute` 方式を採用（[22. 基本設計](22-powershell-design.md)参照） |
| `PSUseBOMForUnicodeEncodedFile` | PowerShell 7前提で、リポジトリ全体をBOMなしUTF-8にそろえているため |

## CIでの実行

`.github/workflows/ci.yml` の `powershell-quality` ジョブが、**ubuntu-latest と windows-latest の両方**で次を実行します。

1. 構文チェック
2. 自動テスト（`Run-PowerShellTests.ps1`）
3. PSScriptAnalyzer

Windowsでも同じテストが通ることを公開の場で確認できるようにしています。ただし、CIのWindowsランナーは**クライアント相当の検証環境**であり、Windows Serverの実機ではありません。上の `NOT RUN` 表はCIが通っても解消されません。

## 証跡テンプレート

```text
テストID:
日時・タイムゾーン:
実行者:
環境([23章](23-powershell-setup.md)のA/B/C/D、OS、PowerShellバージョン、commit):
実行コマンド:
期待結果:
実結果:
終了コード:
判定(PASS/FAIL/NOT RUN):
ログまたはスクリーンショット:
備考・課題ID:
```

FAILを隠してPASSに書き換えないことが大切です。修正後は新しい実行記録を追加し、どのコミットで直ったかを残します。
