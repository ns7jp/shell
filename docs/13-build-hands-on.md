# 13. 構築ハンズオン

この章は [検証環境の構築](03-setup.md) で用意したUbuntu VM（検証環境）がすでにある前提で進めます。対象は「構築する」`scripts/provision_web_server.sh` と、「構築できたか確認する」`scripts/build_verify.sh` の2本です。[初心者向けハンズオン](04-hands-on.md) と同じ演習形式で、1つずつ実際に手を動かします。

## この章の前提

- 設定キーの意味は先に [構築の基本設計](12-build-design.md) を確認してください。
- 終了コードの意味は次のとおりです（`build_verify.sh --help` の表示「終了コード: 0=正常、1=警告あり、2=実行エラー」のとおりです）。

| 終了コード | 意味 |
|---:|---|
| 0 | 正常（`EXIT_OK`、警告なし） |
| 1 | 警告あり（`EXIT_WARNING`） |
| 2 | 実行エラー（`EXIT_ERROR`。設定不備や安全でない値の拒否を含みます） |

## 演習1: ドライランで出力を読む

まず設定ファイルを用意します。既定値のまま使えるので、コピーして権限を絞るだけです。

```bash
cp config/provision.conf.example config/provision.conf
chmod 600 config/provision.conf
./scripts/provision_web_server.sh --config config/provision.conf
```

`--execute` を付けなければ既定でドライランです。何も変更されず、実行予定のコマンドだけが表示されます。出力には、ログ形式（`日時 [LEVEL] メッセージ`）の行と、`run_or_show` 関数が組み立てた `[DRY-RUN] ...` 行が混ざります。`ufw` が入っているUbuntu VMでは、次のような出力になります。

```text
2026-08-29T00:00:00+0000 [INFO] Webサーバー構築を開始します
2026-08-29T00:00:00+0000 [INFO] 対象パッケージ: nginx / サービス名: nginx / 許可ポート: 22 80
2026-08-29T00:00:00+0000 [INFO] パッケージは未導入です。導入します: nginx
[DRY-RUN] env DEBIAN_FRONTEND=noninteractive apt-get update
[DRY-RUN] env DEBIAN_FRONTEND=noninteractive apt-get install -y -- nginx
2026-08-29T00:00:00+0000 [INFO] 配布用サンプルページを準備しました: /var/www/html/index.html
[DRY-RUN] install -D -m 0644 -- /tmp/xxxxxx /var/www/html/index.html
[DRY-RUN] ufw allow 22/tcp
[DRY-RUN] ufw allow 80/tcp
[DRY-RUN] ufw --force enable
2026-08-29T00:00:00+0000 [INFO] [DRY-RUN] systemctl enable --now nginx
2026-08-29T00:00:00+0000 [INFO] ドライラン完了。内容を確認後、検証環境で --execute を指定してください
2026-08-29T00:00:00+0000 [OK] 構築完了: 警告なし
```

問い: `ufw` が入っていないコンテナなどで同じドライランを実行すると、どこが変わるでしょうか。`provision_web_server.sh` は `ufw` の有無を `--execute` の有無に関係なく確認しており、見つからない場合は「`ufw が見つからないためファイアウォール設定をスキップしました（手動確認が必要）`」というWARNを出し、警告を1件加えます。この場合、最終行は「構築完了: 警告 1 件」に変わり、終了コードもドライランのまま1（`EXIT_WARNING`）になります。手元の環境で `echo "$?"` を確認してください。

期待: `ls /var/www/html/index.html` が「そのようなファイルはありません」となること（ドライランでは何も作成されません）。

## 演習2: 検証用VMやコンテナで実際に構築する

`--execute` を付けると、実際にパッケージを導入し、ファイルを配置します。**本番サーバーや共有マシンでは絶対に実行しないでください。** 使い捨てにできる検証用VMやコンテナで行います。

`--execute` にはroot権限が必要です。root権限がない状態で `--execute` を指定すると、「`--execute にはroot権限が必要です（sudoで実行してください）`」というメッセージとともに終了コード2で拒否されます。

```bash
sudo ./scripts/provision_web_server.sh --config config/provision.conf --execute
echo "終了コード=$?"
```

実行後、次を目視で確認します。

```bash
dpkg -s nginx | head -n 3
cat /var/www/html/index.html
```

`--execute` を実行すると、パッケージ導入・ファイル配置に続けてufwとsystemdの設定を試み、最後に自己確認が走って「構築直後の自己確認が完了しました」というOKログが出ます。検証環境によっては、この自己確認より前の2箇所（ufwとsystemd）がWARN（終了コード1）になることがあります。これは安全機構が正しく働いている証拠なので、隠さず記録します。

- systemdが動いていないコンテナ環境では、`systemctl enable --now` に失敗し「systemd経由でのサービス起動に失敗、または未対応の環境です: nginx（手動起動と自動起動設定を確認してください）」という警告になります。実際のUbuntu VMではsystemdが動くため成功する想定です。
- `ufw` が未導入の環境では「ufw が見つからないためファイアウォール設定をスキップしました（手動確認が必要）」という警告になり、ファイアウォール設定はスキップされます。実際のUbuntu VMでは `ufw` を導入したうえで確認する想定です（検証環境に依存します）。

## 演習3: 受け入れ試験の結果をJSON証跡にする

`build_verify.sh` は構築後の受け入れ試験です。`--output` でログをファイルに保存し、既存の `scripts/audit_report.py` でJSON証跡に変換します。使い方は、`server_audit.sh` のログをJSON化したとき（[初心者向けハンズオン](04-hands-on.md) の演習5）とまったく同じです。ログの書式（`日時 [LEVEL] メッセージ`）が共通だからで、`audit_report.py` の側は変更していません。

```bash
./scripts/build_verify.sh --config config/provision.conf --output "$PWD/build-verify.log"
python3 scripts/audit_report.py --input "$PWD/build-verify.log" --output "$PWD/build-verify.json"
status=$?
python3 -m json.tool "$PWD/build-verify.json"
printf '変換終了コード=%s\n' "$status"
```

検証環境でnginxを手動起動した状態で実際に取得したログです（`WEB_ROOT` は既定値の `/var/www/html` に読み替えています）。

```text
2026-08-29T23:48:23+0000 [INFO] 構築後の受け入れ試験を開始します
2026-08-29T23:48:23+0000 [INFO] 対象パッケージ: nginx / サービス名: nginx / ポート: 80
2026-08-29T23:48:23+0000 [OK] パッケージ導入済み: nginx
2026-08-29T23:48:23+0000 [OK] サービス稼働中: nginx
2026-08-29T23:48:23+0000 [OK] 配布ファイルを確認しました: /var/www/html/index.html
2026-08-29T23:48:23+0000 [OK] HTTP応答を確認しました: 80/ -> 200
2026-08-29T23:48:23+0000 [WARN] ufw が見つからないためファイアウォール設定を確認できません
2026-08-29T23:48:23+0000 [WARN] 受け入れ試験完了: 警告 1 件
```

このログを `audit_report.py` に通すと、次のようなJSONになります（`entries` は一部を抜粋しています）。

```json
{
  "schema_version": 1,
  "source": "build-verify.log",
  "result": "WARN",
  "counts": { "INFO": 2, "OK": 4, "WARN": 2, "ERROR": 0 },
  "entries": [
    { "timestamp": "2026-08-29T23:48:23+0000", "level": "OK", "message": "配布ファイルを確認しました: /var/www/html/index.html" },
    { "timestamp": "2026-08-29T23:48:23+0000", "level": "WARN", "message": "ufw が見つからないためファイアウォール設定を確認できません" }
  ]
}
```

期待: `result` が `WARN` のとき、変換自体は成功していても `audit_report.py` の終了コードは1です。パッケージ未導入や不正な行があるなど変換そのものに失敗した場合は終了コード2です。「ファイルができた」だけでなく、`status` の値とJSONの中身を確認してください。

## 演習4: わざと失敗させる

`WEB_ROOT` を危険な値に書き換え、`--execute` を付けずに実行します。`--execute` の有無に関係なく、値の検証は最初に行われるため、ドライランのままで拒否を確認できます。

```bash
cp config/provision.conf config/provision_danger.conf
sed -i 's|^WEB_ROOT=.*|WEB_ROOT=/etc|' config/provision_danger.conf
./scripts/provision_web_server.sh --config config/provision_danger.conf
echo "終了コード=$?"
```

期待: 「`WEB_ROOT に重要なシステムディレクトリそのものは指定できません: /etc`」というメッセージとともに、終了コード2で拒否されます。`/etc` のような重要ディレクトリは、共通関数 `require_absolute_safe_path` が拒否リストで直接ブロックしています。

同様に、`HTTP_PORT` に範囲外の値（1〜65535の外）を指定しても、「`HTTP_PORT は 1 から 65535 の範囲で指定してください`」というメッセージとともに終了コード2で拒否されます。どちらの確認も `--execute` を付けずに行えます。

## 演習5: 冪等性を確認する

同じ構築を2回実行しても、2回目に不要な変更が出ないことを「冪等性」と呼びます（[用語集・チートシート](09-glossary-cheatsheet.md)参照）。`--execute` を2回実行し、出力を見比べます。

```bash
sudo ./scripts/provision_web_server.sh --config config/provision.conf --execute | tee run1.log
sudo ./scripts/provision_web_server.sh --config config/provision.conf --execute | tee run2.log
```

`run1.log` と `run2.log` を見比べます。

- 1回目は「パッケージは未導入です。導入します: nginx」、2回目は「パッケージは導入済みです: nginx」に変わります（`dpkg -s` の判定結果が変わるためです）。
- `apt-get install` の出力はAPT自身が出すメッセージです。2回目の実行では「`nginx is already the newest version`」のような表示になります。実際の文言はOSやパッケージのバージョンによって変わります（検証環境に依存します）。
- `/var/www/html/index.html` の内容は1回目・2回目とも同じで、単に上書きされるだけです。

期待: 2回目の実行でも終了コードが1回目と変わらないこと、そして新規にインストールしたことを示す表示が2回目には出ないことを目視で確認します。

## 覚え方

[用語集・チートシート](09-glossary-cheatsheet.md)にある「受ける・疑う・動かす・確かめる・伝える」の5段階は、構築でも同じ順で使います。

1. **受ける:** `--config` で設定ファイルを受け取ります。
2. **疑う:** `WEB_ROOT` や `HTTP_PORT` などの値を検証し、危険な値は終了コード2で拒否します。
3. **動かす:** ドライランで内容を確認してから、検証用VMやコンテナだけで `--execute` を動かします。
4. **確かめる:** `build_verify.sh` でパッケージ導入・サービス稼働・配布ファイル・HTTP応答を確かめます。
5. **伝える:** ログと終了コード、必要なら `audit_report.py` によるJSON証跡で結果を伝えます。
