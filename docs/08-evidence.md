# 08. 検証証跡

この文書は、確認できた事実と今後実施する作業を分けるための台帳です。環境が変わるたびに、実行日時、OS、Bash、コミットID、コマンド、終了コードを追記してください。

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
| 演習パックの採点器の自己検査 | PASS | `make lab-selfcheck`（模範解答で合格・誤答で不合格を全問検証） |
| 演習パックのShellCheck | PASS | `make lab-lint` 終了0 |
| 学習者本人による演習21問の完走 | NOT RUN | 学習者ごとに実施し、下の「演習パック」節へ記録します |

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

## 演習パック（学習者本人の記録）

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

## 演習パックの検証記録

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
