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
| ShellCheck | NOT RUN | `make lint` の実行記録を追記する |
| GitHub Actions | NOT RUN | push後のActions URLを追記する |
| Ubuntu VM監査 | NOT RUN | VM情報と監査ログが必要 |
| バックアップ作成・復元 | NOT RUN | archiveと`diff -r`結果が必要 |
| ログ圧縮・保持 | NOT RUN | テストログと前後比較が必要 |
| cron/systemd timer | NOT RUN | 登録内容と定期実行ログが必要 |
| 本番環境 | NOT RUN | 本パックの範囲外 |

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

この結果はGit for Windows上のテスト証跡です。Ubuntu VM、systemd、実運用サービスでの確認を代替しません。`make` と `shellcheck` はローカル環境に存在しなかったため `NOT RUN` のままです。

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
