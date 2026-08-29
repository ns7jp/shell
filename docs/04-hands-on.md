# 04. 初心者向けハンズオン

## まず覚える6記号

| 記号 | 読み方 | 意味 |
|---|---|---|
| `$?` | 終了ステータス | 直前のコマンドが成功したか |
| `"$name"` | 変数展開 | 空白を含んでも1つの値として扱う |
| `$(command)` | コマンド置換 | 実行結果を値として使う |
| `[[ ... ]]` | 条件式 | ファイルや文字列を判定する |
| `2>&1` | 出力結合 | エラー出力を標準出力へ合わせる |
| `--` | オプション終端 | `-` で始まるファイル名の誤解釈を防ぐ |

## 演習1: 終了コード

```bash
true
echo "$?"  # 0
false
echo "$?"  # 0以外
```

問い: `false` の直後に別コマンドを実行してから `$?` を見ると何が表示されるでしょうか。終了コードは必ず対象コマンドの直後に確認します。

## 演習2: 監査のしきい値

`config/audit.conf.example` をコピーし、ディスクしきい値を現在値より低くします。

```bash
cp config/audit.conf.example config/audit.conf
chmod 600 config/audit.conf
./scripts/server_audit.sh --config config/audit.conf
result=$?
printf '終了コード=%s\n' "$result"
```

期待: WARNが1件以上なら終了コード1。設定エラーなら2です。

## 演習3: バックアップを復元

バックアップは作るだけでは不十分です。検証用の別ディレクトリへ展開し、元データと比較します。

```bash
mkdir -p "$HOME/shell-lab/restore"
archive=$(find "$HOME/shell-lab/backups" -name '*.tar.gz' -type f | sort | tail -n 1)
tar -xzf "$archive" -C "$HOME/shell-lab/restore"
diff -r "$HOME/shell-lab/source" "$HOME/shell-lab/restore/source"
echo "$?"
```

期待: `diff` の出力がなく終了コード0。違いがあれば、アーカイブ、展開先、元データの更新時刻を調べます。

## 演習4: わざと失敗させる

設定の `SOURCE_DIR=/` としてドライランしてください。危険なパスとして終了コード2になれば、安全機構を確認できています。`--execute` は付けないでください。

## 覚え方

「引数を受ける → 値を疑う → 処理する → 結果を再確認する → 終了コードで伝える」の5段階を、どのスクリプトでも同じ順に探してください。

## 演習5: PythonでJSON証跡を作る

監査の `--output` でログを保存し、Pythonへ渡します。Bashがサーバーを調べ、Pythonが報告しやすい形へ整える流れです。

```bash
./scripts/server_audit.sh --config config/audit.conf --output "$PWD/audit.log"
python3 scripts/audit_report.py --input "$PWD/audit.log" --output "$PWD/audit.json"
status=$?
python3 -m json.tool "$PWD/audit.json"
printf '変換終了コード=%s\n' "$status"
```

JSONの `counts` はレベル別件数、`result` は総合判定、`entries` は明細です。`WARN` があれば変換に成功しても終了1、不正な行や読取失敗なら終了2です。「ファイルができた」だけでなく、終了コードと中身を確認してください。
