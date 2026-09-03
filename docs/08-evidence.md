# 08. 検証証跡

この文書は、確認できた事実と今後実施する作業を分けるための台帳です。環境が変わるたびに、実行日時、OS、Bash/PowerShellのバージョン、コミットID、コマンド、終了コードを追記してください。

## 判定の意味

- `PASS`: 記載環境で実行し、期待結果と一致した。
- `FAIL`: 実行したが期待結果と一致しなかった。
- `NOT RUN`: 未実施。予定や推測を成功実績として扱わない。

## 現在の台帳

| 項目 | 状態 | 証跡 |
|---|---|---|
| Bash構文検証 | PASS | 2026-08-28、Git for Windows Bash 5.3.15、全5ファイル `bash -n` 終了0 |
| 自己完結テスト | PASS | 2026-08-28、Git for Windows Bash 5.3.15、12/12成功、終了0 |
| ShellCheck | PASS (CI) | PR #1、Ubuntu runner、`shell-quality`、2026-08-28 |
| GitHub Actions | PASS | PR #1、コミット `aa5a3fa` で `All checks have passed` を確認 |
| Ubuntu VM監査 | NOT RUN | VM情報と監査ログが必要 |
| バックアップ作成・復元 | NOT RUN | archiveと`diff -r`結果が必要 |
| ログ圧縮・保持 | NOT RUN | テストログと前後比較が必要 |
| cron/systemd timer | NOT RUN | 登録内容と定期実行ログが必要 |
| 本番環境 | NOT RUN | 本パックの範囲外 |
| 構築スクリプトのBash構文検証 | PASS | 2026-08-29、`bash -n`全対象ファイル終了0 |
| 構築スクリプトの自己完結テスト | PASS | 2026-08-29、`bash tests/run_tests.sh` 26/26成功、終了0 |
| 構築スクリプトのShellCheck | PASS | 2026-08-29、ShellCheck 0.9.0、`make lint`終了0 |
| コンテナでのnginx構築(`provision_web_server.sh --execute`) | PASS（要約はNOT RUN欄参照） | 2026-08-29、nginx導入とサンプルページ配置は成功、systemd/ufwは環境未対応でWARN、終了1 |
| 受け入れ試験(`build_verify.sh`) | PASS | 2026-08-29、nginx手動起動後、パッケージ/サービス/配布ファイル/HTTP応答の4項目OK、ufw未導入で警告1件、終了1 |
| 構築ログのJSON証跡化 | PASS | 2026-08-29、既存の`audit_report.py`を再利用してJSON化、終了1（WARN由来） |
| 実Ubuntu VMでの構築・再起動後のsystemd自動起動 | NOT RUN | コンテナにはsystemdがなく確認不能。実VMでの確認が必要 |
| 実ufw導入によるポート到達性の確認 | NOT RUN | コンテナに`ufw`が未導入。実VMでの確認が必要 |
| Ansible等による構成管理の再現性 | NOT RUN | [構築ロードマップ](10-server-build-roadmap.md)のPhase 2相当、未着手 |
| Bash演習パックの採点器の自己検査 | PASS | `make lab-selfcheck`（模範解答で合格・誤答で不合格を全問検証） |
| Bash演習パックのShellCheck | PASS | `make lab-lint` 終了0 |
| 学習者本人によるBash演習21問の完走 | NOT RUN | 学習者ごとに実施し、下の「Bash演習パック」節へ記録します |
| Windows実機での点検値の取得（CPU・メモリ・サービス・イベントログ） | NOT RUN | `Get-CimInstance` / `Get-Service` / `Get-WinEvent` はLinuxに存在せず、CIのWindowsジョブでも実サーバーへの点検を回していない（[25. テスト仕様](25-powershell-test-plan.md)のPS-46） |
| PowerShell構文検証 | PASS | 2026-09-03、PowerShell 7.4.6 (Linux)、対象7ファイル（実装6 + テスト1）、`make ps-syntax` 終了0 |
| PowerShell自動テスト | PASS | 2026-09-03、`Run-PowerShellTests.ps1` 66/66成功、終了0、追加モジュール不要 |
| PowerShell点検スクリプトの実行 | PASS | 2026-09-03、Linux上で `Invoke-ServerAudit.ps1` 実行、Windows専用コマンド不在の2項目をWARN、終了1 |
| PowerShellログのJSON証跡化 | PASS | 2026-09-03、既存の `audit_report.py` を無改修で再利用、`result=WARN`、終了1 |
| PowerShell構築スクリプトのドライラン | PASS | 2026-09-03、`Install-WebServer.ps1`（`-Execute` なし）でファイル未作成を確認、終了1（環境依存の警告3件） |
| PowerShell構築スクリプトのOS・権限拒否 | PASS | 2026-09-03、Linuxで `-Execute` を指定すると実行前に終了2で拒否 |
| PowerShellバックアップの作成と整合性確認 | PASS | 2026-09-03、`New-DataBackup.ps1 -Execute` でZIP作成、開いて1件を確認、終了0 |
| PowerShellログ保守 | PASS | 2026-09-03、`Invoke-LogMaintenance.ps1 -Execute` で圧縮後に元ログ0バイト、終了0 |
| PowerShell設定検証（フェイルクローズ） | PASS | 2026-09-03、危険パス・範囲外の値・必須欠落・処理入り`.psd1`をすべて終了2で拒否 |
| PSScriptAnalyzer（PowerShell静的解析・ローカル） | NOT RUN | 2026-09-03、検証環境からPowerShell Galleryへ到達できずインストール不可。**CIでは実行済み**（下の「PSScriptAnalyzer（CI上）」行を参照）。NOT RUN はローカル環境に限った話 |
| Windows実機でのIIS構築（`Install-WebServer.ps1 -Execute`） | NOT RUN | Windows実機が必要。役割導入・サービス自動起動・ファイアウォール規則は未確認 |
| Windows実機での受け入れ試験（全項目OK） | NOT RUN | 構築が未実施のため。Linuxでは5項目すべてWARNになることのみ確認済み |
| Windows再起動後のサービス自動起動 | NOT RUN | 再起動をまたぐ確認は実機VMが必要 |
| ファイアウォール許可後の別端末からの到達性 | NOT RUN | 2台以上のネットワーク環境が必要 |
| タスクスケジューラでの定期実行 | NOT RUN | 登録スクリプトは本パックに含めていない |
| GitHub ActionsのPowerShellジョブ（ubuntu-latest） | PASS | 2026-09-03、コミット`307c406`で構文チェック・自動テスト・PSScriptAnalyzerすべて成功。初回コミット`146a1b2`では`PSUseSingularNouns`を1件指摘され失敗 |
| GitHub ActionsのPowerShellジョブ（windows-latest） | PASS | 2026-09-03、コミット`307c406`で `1..58 / pass=58 fail=0`、PSScriptAnalyzerも `PSScriptAnalyzer OK`。初回コミット`146a1b2`では `pass=54 fail=2`（PS-16がWindowsでのみ失敗） |
| PSScriptAnalyzer（CI上） | PASS | 2026-09-03、ubuntu-latest・windows-latestの両方で指摘0件。ローカル環境ではPowerShell Galleryへ到達できず実行不可 |
| Windows上でのPowerShell自動テスト | PASS | 2026-09-03、windows-latestランナー（Microsoft Windows Server 2025 / 10.0.26100 Datacenter、イメージ `windows-2025-vs2026`。ジョブログの「Operating System」で確認）。コミット`b28d3c4`で63/63成功（同コミットのLinuxは66件。差はOSごとに対象外・確認内容が変わるため） |

## ローカル検証記録

```text
日時: 2026-08-28 Asia/Tokyo
環境: Windows + Git for Windows Bash 5.3.15
commit: 作業ツリー（未コミット）
command: find scripts tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
exit code: 0
result: PASS
evidence: 全対象ファイルの構文エラーなし

command: bash tests/run_tests.sh
exit code: 0
result: PASS
evidence: pass=12 fail=0

command: git diff --check
exit code: 0
result: PASS
evidence: whitespace errorなし（改行コード変換の警告はあり）
```

この結果はGit for Windows上のローカルテスト証跡です。Ubuntu VM、systemd、実運用サービスでの確認を代替しません。ローカルの `make lint` はShellCheckが存在しなかったため `NOT RUN` ですが、GitHub ActionsのUbuntu runnerではShellCheckを実行してPASSしました。

## 構築パック(provision_web_server.sh / build_verify.sh)の検証記録

```text
日時: 2026-08-29 UTC
環境: Linuxコンテナ、Ubuntu 24.04.4 LTS、root、GNU bash 5.2.21(1)-release
commit: 作業ツリー（未コミット）

command: bash -n scripts/provision_web_server.sh && bash -n scripts/build_verify.sh
exit code: 0
result: PASS
evidence: 両ファイルとも構文エラーなし

command: bash tests/run_tests.sh
exit code: 0
result: PASS
evidence: pass=26 fail=0（既存12件 + 構築パック14件）

command: shellcheck scripts/provision_web_server.sh scripts/build_verify.sh scripts/lib/*.sh
exit code: 0
result: PASS
evidence: 指摘なし（ShellCheck 0.9.0）

command: ./scripts/provision_web_server.sh --config provision.conf --execute
exit code: 1
result: PASS（警告2件は環境依存のため想定どおり）
evidence: nginx導入とサンプルページ配置は成功。コンテナにsystemdが無いため
  systemctl enable --now は失敗しWARN、ufw未導入のためファイアウォール設定もWARN。
  実Ubuntu VMではこの2件はsystemd/ufwが動作するため解消される見込み。

command: nginxを手動起動した後の ./scripts/build_verify.sh --config provision.conf --output build-verify.log
exit code: 1
result: PASS
evidence: パッケージ導入済み[OK] / サービス稼働中[OK] / 配布ファイル確認[OK] /
  HTTP応答200[OK] / ufw未導入[WARN]。詳細は examples/build-verify-output.md 参照。

command: python3 scripts/audit_report.py --input build-verify.log --output build-verify.json
exit code: 1
result: PASS
evidence: schema_version 1のJSONを作成。counts={"INFO":2,"OK":4,"WARN":2,"ERROR":0}、
  result="WARN"。server_audit.sh用に作った既存スクリプトをそのまま再利用できた。

command: ./scripts/provision_web_server.sh --config provision.conf --execute （設定エラー系）
exit code: 2
result: PASS
evidence: WEB_ROOT=/etc、HTTP_PORT範囲外、PACKAGE_NAME欠落のいずれも実行前に拒否
  され、システムへの変更は発生しなかった。
```

コンテナ環境の制約（systemdがPID 1でない、ufw未導入）で確認できなかった項目は、上の台帳で `NOT RUN` として明記しています。実Ubuntu VMでの構築、再起動後の自動起動確認、実ufw有効化は別途実施が必要です。

実行後は次の形式で追記します。

```text
日時:
環境:
commit:
command:
exit code:
result: PASS / FAIL
evidence:
```

スクリーンショットだけでなく、再現可能なテキストログとコマンドを優先します。秘密情報、ユーザー名、内部IP、ホスト名は公開前にマスキングしてください。

## Bash演習パック（学習者本人の記録）

[Bash演習案件パック](15-exercise-pack-guide.md)の達成記録を残す場所です。判定の意味は上と同じで、`PASS` / `FAIL` / `NOT RUN` を使います。

進捗表は次のコマンドで出力し、生成された `progress.md` の表をここへ貼ります。

```bash
bash exercises/labctl.sh progress --save
cat "$HOME/bash-lab/progress/progress.md"
```

1問ぶんの証跡は、[テスト仕様](05-test-plan.md)と同じテンプレート形式で出力できます。

```bash
bash exercises/labctl.sh evidence E09
```

| 項目 | 状態 | 証跡 |
|---|---|---|
| L0（E01〜E03） | NOT RUN | 進捗表を貼る |
| L1（E04〜E06） | NOT RUN | 進捗表を貼る |
| L2（E07〜E09） | NOT RUN | 進捗表を貼る |
| L3（E10〜E12） | NOT RUN | 進捗表を貼る |
| L4（E13〜E15） | NOT RUN | 進捗表を貼る |
| L5（E16〜E18） | NOT RUN | 進捗表を貼る |
| L6（E19〜E21） | NOT RUN | 進捗表を貼る |
| 自由再生テスト（`labctl recall`） | NOT RUN | `recall.log` の合格記録（日付が2種類以上） |

面接では、この表を「何を実施し、何をまだ実施していないか」の順で説明します。未実施を実施済みとして扱わないことが、この台帳の目的です。

## Bash演習パックの検証記録

```text
日時: 2026-09-03 UTC
環境: Ubuntu / Bash 5.2.21 / Python 3.11.15 / ShellCheck 0.9.0
commit: ce5052f

command: make check
exit code: 0
result: PASS
evidence: 既存テスト 26/26 成功（演習パックの追加後も変化なし）

command: make lint
exit code: 0
result: PASS
evidence: 既存スクリプトの ShellCheck 指摘なし

command: make lab-lint
exit code: 0
result: PASS
evidence: 演習パックの ShellCheck 指摘なし（SC1090/SC1091 は source 追跡の制限として除外）

command: make lab-selfcheck
exit code: 0
result: PASS
evidence: 採点器の自己検査 46/46、採点ツールのテスト 37/37
          （模範解答で合格21件・誤答で不合格24件・カード検査1件）

command: 一般ユーザー(labtest)での make check / make lab-lint / make lab-selfcheck
exit code: 0
result: PASS
evidence: root以外でも同じ結果。doctor は警告0件

command: GitHub Actions (shell-quality / exercise-pack)
result: PASS
evidence: PR #8、Ubuntu runner（非root）で両ジョブ成功
```

### 採点器に対して実際に試した攻撃と結果

敵対的レビューで再現した欠陥は修正済みです。修正後に同じ手順で再確認しました。

| 試したこと | 修正前 | 修正後 |
|---|---|---|
| 検証を書いていない答案で E12 / E19 を採点 | `/etc` と `/` に実際に書き込めた | `/proc` を使うため書き込み不可。システムは無変更 |
| 学習者のテストから被テストスクリプトへ書き込む（E14） | リポジトリ内の模範解答を壊せた | サンドボックスの複製のみ。リポジトリは無変更 |
| 大量出力を出す答案 | 一時領域のピークが 10.4GB | 上限20MBで打ち切り、ピーク 60MB |
| 停止要求を無視する答案 | 採点が返らない（無限） | 61秒で確実に終了 |
| `&` で裏に流す答案 | 孤児プロセスが残り CPU を占有 | 採点のたびに回収、残留 0本 |
| 雛形の指示どおりに埋めた正答（E17） | 必ず不合格になった | 合格する |
| `--execute` を実装しない答案（E05 / E06） | 満点で合格した | 不合格になる |

### まだ実施していないこと

| 項目 | 状態 | 必要な証跡 |
|---|---|---|
| 学習者本人による21問の完走 | NOT RUN | `labctl progress --save` の出力 |
| WSL2 での通し実行 | NOT RUN | CRLF 環境での採点結果 |
| 実 Ubuntu VM での通し実行 | NOT RUN | 環境情報と採点ログ |
| 21日間の復習サイクルの実運用 | NOT RUN | `progress.tsv` の次回期日の推移 |
## PowerShell演習パックの検証記録

```text
日時: 2026-09-03 UTC
環境: Linuxコンテナ、Ubuntu 24.04.4 LTS、root、PowerShell 7.4.6
commit: 作業ツリー（未コミット）

command: make ps-syntax
exit code: 0
result: PASS
evidence: scripts/powershell と tests/powershell の7ファイル（実装6 + テスト1）すべてで構文エラーなし
  （PowerShellのパーサー [System.Management.Automation.Language.Parser]::ParseFile で確認）

command: pwsh -NoProfile -File tests/powershell/Run-PowerShellTests.ps1
exit code: 0
result: PASS
evidence: pass=66 fail=0。追加モジュール（Pester等）のインストールなしで完走。
  Windows専用の確認を含むPS-07・PS-25は、この環境では実行対象（Linux側）として通過。

command: pwsh -NoProfile -File scripts/powershell/Invoke-ServerAudit.ps1 --ConfigPath ... --OutputPath audit.log
exit code: 1
result: PASS（警告2件は環境依存のため想定どおり）
evidence: CPU・メモリ・ディスク・ログディレクトリはOK。Get-Service と Get-WinEvent が
  存在しないためWARN 2件。実際の出力は examples/powershell-audit-output.md に掲載。

command: python3 scripts/audit_report.py --input audit.log --output audit.json
exit code: 1
result: PASS
evidence: schema_version 1 のJSONを作成。counts={"INFO":4,"OK":4,"WARN":3,"ERROR":0}、
  result="WARN"。Bash版のために作った既存スクリプトを1行も変更せずに再利用できた。

command: pwsh -NoProfile -File scripts/powershell/Install-WebServer.ps1 -ConfigPath ...
exit code: 1
result: PASS（ドライラン。警告3件は環境依存）
evidence: [DRY-RUN] 行を表示し、WebRoot に index.html は作成されなかった。
  Windows専用コマンド（役割導入・ファイアウォール・サービス）が無いためWARN 3件。

command: pwsh -NoProfile -File scripts/powershell/Install-WebServer.ps1 -ConfigPath ... -Execute
exit code: 2
result: PASS
evidence: 「この構築処理はWindowsでのみ実行できます」で実行前に拒否。システムへの変更なし。

command: pwsh -NoProfile -File scripts/powershell/New-DataBackup.ps1 -ConfigPath ... -Execute
exit code: 0
result: PASS
evidence: ZIPを作成後、[System.IO.Compression.ZipFile]::OpenRead で開いて1件を確認。
  ドライラン時はファイルが作られないことも確認済み。

command: pwsh -NoProfile -File scripts/powershell/Invoke-LogMaintenance.ps1 -ConfigPath ... -Execute
exit code: 0
result: PASS
evidence: 5日前の app.log を圧縮し、圧縮成功を確認してから元ログを0バイトにした。

command: 設定検証系（危険パス、範囲外の値、必須項目の欠落、処理が書かれた .psd1）
exit code: 2（すべて）
result: PASS
evidence: いずれも処理を始める前に拒否。特に処理が書かれた .psd1 は
  Import-PowerShellDataFile がデータ以外を読まないため、コマンドは実行されなかった。

command: Install-Module PSScriptAnalyzer
exit code: -
result: NOT RUN
evidence: 検証環境からPowerShell Galleryへ到達できず（プロキシで拒否）。
  なお、CIの powershell-quality ジョブでは実行済みで、ubuntu-latest・windows-latestとも指摘0件。
  この NOT RUN はローカル環境に限った話。
```

この結果は**Linux上のPowerShell 7による検証**です。Windows Server実機でのIIS導入、サービスの自動起動、ファイアウォール規則の作成と到達性は確認できていません。上の台帳で `NOT RUN` と明記しています。

Windows専用コマンドが存在しない環境で警告になる項目は、[25. テスト仕様](25-powershell-test-plan.md)の `NOT RUN` 表と対応しています。**「Linuxで動いた」ことを「Windowsで動く」と書き換えないでください。**

### CIで見つかった不具合（2026-09-03）

Windows実機を持っていなくても、CIのwindows-latestジョブがあれば見つけられる不具合がありました。記録として残します。

```text
症状: PS-16「保存先が保存元の中なら終了コード2」がWindowsでだけ失敗（実際は終了0）
原因: 設定に C:\...\source/inner のように区切り文字が混在していると、
      Assert-OpsSafePath が正規化していなかったため、New-DataBackup.ps1 の
      「保存先が保存元の配下か」という文字列比較がすり抜けていた。
      Windowsは \ と / の両方を区切りとして受け付けるため、Linuxでは再現しない。
影響: 安全機構（フェイルクローズ）が働かず、保存先を保存元の中に置けてしまう。
修正: Assert-OpsSafePath で、Windowsのときに / を \ へそろえてから判定するようにした。
回帰テスト: PS-30 を追加（両OSで、区切り文字と末尾がOSの形にそろうことを確認）。

症状: PSScriptAnalyzer が PSUseSingularNouns を1件指摘（ubuntu-latest）
原因: テスト用関数 Assert-OutputContains の名詞が複数形と判定された。
修正: Assert-OutputContainsText に改名。規則の除外は増やしていない。
```

### レビューで見つかった不具合（2026-09-03）

成果物を4観点でレビューし、実行して再現できた指摘を修正しました。安全機構に関わるものを挙げます。

```text
症状: 保護ディレクトリの判定が、同じ場所を指す別の書き方ですり抜ける
再現: Assert-OpsSafePath -Name T -Path '/tmp'    -> 終了2（拒否・正しい）
      Assert-OpsSafePath -Name T -Path '//tmp'   -> 終了0（すり抜け）
      Assert-OpsSafePath -Name T -Path '/./tmp'  -> 終了0（すり抜け）
      Assert-OpsSafePath -Name T -Path '///tmp'  -> 終了0（すり抜け）
      ls -di /tmp //tmp /./tmp  → いずれも同じ inode（同一ディレクトリ）
原因: 文字列をそのまま比較していたため、書き方の違いを吸収できていなかった。
      先にCIのWindowsジョブで見つかった「区切り文字の混在」と同じ種類の見落とし。
影響: 「重要ディレクトリそのものは拒否する」というフェイルクローズが無効になる。
修正: [System.IO.Path]::GetFullPath で正規化してから判定するようにした。
      Windowsの \ と / の混在も、この1か所でまとめて吸収される。
回帰テスト: PS-03 に別の書き方（//etc、/./etc、///etc、/etc/ ／WindowsはC:\\Windows等）を追加。

症状: READMEと各章が案内する config/powershell/*.psd1.example を
      -ConfigPath にそのまま渡すと、どのOSでも終了コード2で失敗する
原因: 拡張子を .psd1 に限定していたため（Get-Item の Extension は .example を返す）。
影響: 初心者が最初に打つコマンドが動かない。
修正: .psd1 と .psd1.example の両方を受け付けるようにした。回帰テスト PS-31 を追加。
```

これらはLinuxでもWindowsでも再現する不具合で、**自動テストが全件通っている状態でも残っていました。**
「テストが緑であること」と「安全機構が本当に働くこと」は別だ、という実例として記録します。

**Linuxだけで検証していたら、どちらも見逃していました。** 「両方のOSでCIを回す」ことの効果が実際に出た例です。

現在のCI結果（コミット `b28d3c4`）は次のとおりです。

```text
shell-quality (ubuntu-latest)              success
powershell-quality (ubuntu-latest)         success   自動テスト 66/66、PSScriptAnalyzer 指摘0件
powershell-quality (windows-latest)        success   自動テスト 63/63（1..63 / pass=63 fail=0）、PSScriptAnalyzer 指摘0件
```

Windowsが3件少ないのは、PS-07とPS-25が対象外になること（各1行に集約）に加えて、
PS-03が「同じ場所を指す別の書き方」をOSごとに変えて試す（Linuxは4通り、Windowsは3通り）ためです。
**件数が環境で違うこと自体を説明できる状態**にしてあり、合格条件は件数ではなく `fail=0` です。

参考までに、修正前のコミット `307c406` の結果は次のとおりでした。

```text
shell-quality (ubuntu-latest)              success
powershell-quality (ubuntu-latest)         success   自動テスト 60/60、PSScriptAnalyzer 指摘0件
powershell-quality (windows-latest)        success   自動テスト 58/58（1..58 / pass=58 fail=0）、PSScriptAnalyzer 指摘0件
```

Windowsの件数が2件少ないのは、PS-07（ファイル権限の確認）とPS-25（Windows以外での `-Execute` 拒否）が
Windowsでは対象外となり、スキップした旨を1行で記録するためです。件数が環境で変わること自体を
「対象外と記録した結果」として説明できる状態にしてあります。

**上の件数はコミット `307c406` 時点の実測値です。** その後テストを追加したため件数は増えています
（PS-30・PS-31の追加により、Linuxで62件）。件数はテストを足せば変わるので、
合格条件は件数ではなく `fail=0` です。

**このCIランナーはWindows Server 2025ですが、ジョブが実行しているのはドライランと検証ロジックまでで、IISを実際に構築したわけではありません。**
役割の導入・サービスの自動起動・ファイアウォール規則の作成と到達性は、上の台帳のとおり `NOT RUN` のままです。
