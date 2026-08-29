# 構築受け入れ試験の出力の読み方

`build_verify.sh` は `config/provision.conf.example` に書いた望ましい状態（パッケージ、サービス、配布ファイル、ポート、ファイアウォール）を、実際のサーバーに問い合わせて確認します。

```text
2026-01-01T09:10:00+0900 [INFO] 構築後の受け入れ試験を開始します
2026-01-01T09:10:00+0900 [INFO] 対象パッケージ: nginx / サービス名: nginx / ポート: 80
2026-01-01T09:10:00+0900 [OK] パッケージ導入済み: nginx
2026-01-01T09:10:00+0900 [OK] サービス稼働中: nginx
2026-01-01T09:10:00+0900 [OK] 配布ファイルを確認しました: /var/www/html/index.html
2026-01-01T09:10:00+0900 [OK] HTTP応答を確認しました: 80/ -> 200
2026-01-01T09:10:00+0900 [WARN] ufw が見つからないためファイアウォール設定を確認できません
2026-01-01T09:10:00+0900 [WARN] 受け入れ試験完了: 警告 1 件
```

これは説明用の例であり、実サーバーの実行証跡ではありません。上から4項目（パッケージ、サービス、配布ファイル、HTTP応答）は `provision_web_server.sh` の実行後に実際にコンテナ環境で確認できた結果を反映しています。最後の1件は、この環境に `ufw` が導入されていないために生じた警告で、正常な設計どおりの挙動です。実際のUbuntu VMで `ufw` を導入していれば、この行も `OK` になります。

終了コードは `server_audit.sh` と同じ考え方です。0は全項目OK、1は警告あり、2は設定不備などの実行エラーです。次のように既存の `audit_report.py` へそのまま渡してJSON証跡に変換できます（新しいPythonスクリプトは作っていません）。

```bash
./scripts/build_verify.sh --config config/provision.conf --output "$PWD/build-verify.log"
python3 scripts/audit_report.py --input "$PWD/build-verify.log" --output "$PWD/build-verify.json"
```

`server_audit.sh` の点検ログと書式（`日時 [LEVEL] メッセージ`）が同じであるため、変換スクリプトを増やさずに済んでいます。
