# PowerShell受け入れ試験の出力の読み方

`scripts/powershell/Test-WebServerBuild.ps1` は、`Install-WebServer.ps1` と**同じ設定ファイル**に書いた「望ましい状態」を、実際のサーバーに問い合わせて確認します。何も変更しません。

確認するのは5項目です。

| 確認項目 | 使うコマンド |
|---|---|
| 役割（IIS）が導入されているか | `Get-WindowsFeature` / `Get-WindowsOptionalFeature` |
| サービスが稼働しているか | `Get-Service` |
| 配布ファイルがあるか | `Test-Path` |
| HTTPが応答するか | `Invoke-WebRequest` |
| ファイアウォールで許可されているか | `Get-NetFirewallRule` |

## 構築が成功したWindows Serverでの出力（説明用の例）

```text
2026-01-01T09:10:00+0900 [INFO] 構築後の受け入れ試験を開始します
2026-01-01T09:10:00+0900 [INFO] 対象役割: Web-Server / サービス名: W3SVC / ポート: 80
2026-01-01T09:10:00+0900 [OK] 役割導入済み: Web-Server
2026-01-01T09:10:00+0900 [OK] サービス稼働中: W3SVC
2026-01-01T09:10:00+0900 [OK] 配布ファイルを確認しました: C:\inetpub\wwwroot\index.html
2026-01-01T09:10:01+0900 [OK] HTTP応答を確認しました: http://127.0.0.1:80/ -> 200
2026-01-01T09:10:01+0900 [OK] ファイアウォール許可を確認しました: ops-lab-http-80 (80/tcp)
2026-01-01T09:10:01+0900 [OK] 受け入れ試験完了: 警告なし
```

これは説明用の架空例です。Windows実機での実行は[検証証跡](../docs/08-evidence.md)で `NOT RUN` としています。

## 未構築の環境での実際の出力

こちらは**このリポジトリの検証環境（Linux・IIS未構築）で実際に実行した結果**です。

```text
2026-09-03T06:19:31+0000 [INFO] 構築後の受け入れ試験を開始します
2026-09-03T06:19:31+0000 [INFO] 対象役割: Web-Server / サービス名: W3SVC / ポート: 80
2026-09-03T06:19:31+0000 [WARN] 役割を確認するコマンドが無いため確認できません(Windows以外の環境です)
2026-09-03T06:19:31+0000 [WARN] Get-Service が無いためサービス状態を確認できません(Windows以外の環境です)
2026-09-03T06:19:31+0000 [WARN] 配布ファイルが見つかりません: /home/user/ps-lab/wwwroot/index.html
2026-09-03T06:19:31+0000 [WARN] HTTP応答を確認できません: http://127.0.0.1:80/ -> 0
2026-09-03T06:19:31+0000 [WARN] Get-NetFirewallRule が無いためファイアウォール設定を確認できません(Windows以外の環境です)
2026-09-03T06:19:31+0000 [WARN] 受け入れ試験完了: 警告 5 件
```

終了コードは `1` です。5件の警告は、それぞれ理由が違います。

| 警告 | 理由 | Windows実機では |
|---|---|---|
| 役割を確認するコマンドが無い | Windows専用コマンドが存在しない | `OK` または「役割未導入」になる |
| `Get-Service` が無い | 同上 | `OK` または「サービス停止」になる |
| 配布ファイルが見つかりません | まだ構築していない | 構築後は `OK` |
| HTTP応答を確認できません（`-> 0`） | 応答が無い。`0` は「HTTPステータスすら得られなかった」印 | 構築後は `-> 200` |
| `Get-NetFirewallRule` が無い | Windows専用コマンドが存在しない | 規則があれば `OK` |

**「確認できなかった」と「確認したら駄目だった」を、メッセージで区別できるようにしてあります。** どちらも `WARN` ですが、次にやることが違うためです。

## 終了コードとJSON証跡

考え方は `Invoke-ServerAudit.ps1` と同じです。0は全項目OK、1は警告あり、2は設定不備などの実行エラーです。

```powershell
pwsh -NoProfile -File scripts\powershell\Test-WebServerBuild.ps1 -ConfigPath C:\ops-lab\websetup.psd1 -OutputPath C:\ops-lab\build-verify.log
python3 scripts\audit_report.py --input C:\ops-lab\build-verify.log --output C:\ops-lab\build-verify.json
```

Bash版の `build_verify.sh` と書式が同じなので、**Windows側とLinux側の受け入れ試験の証跡が、同じJSON形式で並びます。** 監査担当が2つの形式を覚える必要がありません。

## 構築スクリプトのドライラン出力について

`Install-WebServer.ps1` のドライラン表示（`[DRY-RUN] ...`）は、日時と `[LEVEL]` を伴わない行です。この形のままでは `audit_report.py` の行形式と一致しません。証跡化は、すべての行が `Write-OpsLog` を通る `Test-WebServerBuild.ps1` や `Invoke-ServerAudit.ps1` の出力に対して行ってください。この制約はBash版パックとまったく同じです。
