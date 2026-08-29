# 12. 構築の基本設計

## 全体構成

この構築パックは、Webサーバーを**作る**役目と、作った結果を**確かめる**役目を別のスクリプトに分けています。両方とも同じ共通ライブラリと同じ設定ファイルを使うため、構築時に使った値と確認時に使う値がずれません。

```text
利用者
  └─ --config / --execute
       ├─ provision_web_server.sh ── 導入・配置・ufw・systemd ── パッケージ → Webサーバー一式
       └─ build_verify.sh ──────── 確認 ─────────────────────── Webサーバー → OK/WARN判定
               └─ scripts/lib/common.sh（ログ、検証、終了コード）
       └─ audit_report.py ── 解析 ── 構築ログ → JSON証跡
```

`provision_web_server.sh` はパッケージ導入、サンプルページ配置、ufw（Ubuntu標準のファイアウォール管理コマンド）設定、systemd（Linuxでサービスの起動・自動起動を管理する仕組み）への登録までを担当します。`build_verify.sh` はその結果を後から確認するだけで、何も変更しません。既存の `audit_report.py`（[02. 基本設計](02-design.md)で使っているログ→JSON変換スクリプト）は、構築系のログもそのまま読み込めます。理由は後述します。

## ネットワーク構成とポート

[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)で描いた最小構成をもとに、実装した経路は次のとおりです。

```text
手元PC
  └─ SSH(22/tcp) / HTTP(80/tcp)
       └─ Ubuntu VM
            ├─ ufw（firewall）───────────── 22/tcp・80/tcpのみ許可、それ以外は拒否
            ├─ nginx（PACKAGE_NAME）────── provision_web_server.sh --execute で導入
            ├─ WEB_ROOT/index.html ────── 静的なサンプルページ
            ├─ systemd（SERVICE_NAME）── enable --now で自動起動を設定
            └─ build_verify.sh / audit_report.py ── 構築後の点検・証跡化
```

許可するポートは次の方針です。

| ポート/プロトコル | 用途 | 既定の扱い |
|---|---|---|
| 22/tcp | SSH管理用 | 許可 |
| 80/tcp | HTTPアクセス用 | 許可 |
| それ以外 | - | 拒否 |

学習環境は外部公開せず、NATまたはホストオンリーネットワークを使う方針は[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)を引き継いでいます。

## 設定ファイルの役割分担

`config/provision.conf.example` の各キーは、対象システムの「望ましい状態」を1箇所で定義するためのものです。

| 設定キー | 意味 | 実際に使うスクリプト |
|---|---|---|
| `PACKAGE_NAME` | 導入・確認するパッケージ名 | 両方（provisionはapt-get installで導入、build_verifyは`dpkg -s`で確認） |
| `SERVICE_NAME` | systemdで有効化・確認するサービス名 | 両方 |
| `WEB_ROOT` | 配布ファイル（index.html）を置く絶対パス | 両方 |
| `SITE_TITLE` | サンプルページの`<title>`と見出しに使う文字列 | provision_web_server.shのみ |
| `ALLOWED_TCP_PORTS` | ufwで許可するTCPポート一覧（空白区切り、既定 `22 80`） | provision_web_server.shのみ |
| `HTTP_PORT` | 確認するHTTPポート番号（既定80） | 両方（provisionは範囲検証のみ、build_verifyはHTTP応答の確認先） |
| `HEALTHCHECK_PATH` | HTTP応答を確認するパス（既定 `/`、`/`から始まる必要あり） | build_verify.shのみ |

構築(`provision_web_server.sh`)と受け入れ試験(`build_verify.sh`)が同じ設定ファイルを共有する設計にしたのは、対象システムの望ましい状態を1箇所で定義するためです。設定ファイルを分けると、構築後に`WEB_ROOT`や`HTTP_PORT`を変更したときに試験側の更新を忘れ、誤ったOK判定や誤ったWARNを出すおそれがあります。1つの設定ファイルを両方が読むことで、「作った内容」と「確認する内容」が常に一致します。

## BashとPythonの役割分担

[02. 基本設計](02-design.md)と同じ方針で、Bashはパッケージ導入・ファイル配置・ufw・systemdといったOS操作に使い、Pythonはログの解析・集計・JSON生成に使います。

構築パックでも新しいPythonスクリプトは作らず、既存の`audit_report.py`をそのまま再利用しています。理由は、`scripts/lib/common.sh`の`log()`関数がすべてのスクリプトで同じ書式「日時 `[LEVEL]` メッセージ」（例: `2026-08-29T23:48:23+0000 [OK] パッケージ導入済み: nginx`）でログを出しているためです。`audit_report.py`の`LOG_PATTERN`（正規表現）はこの書式だけを読み取れる作りなので、`provision_web_server.sh`や`build_verify.sh`のログもフォーマットを変えずに書けば、そのままJSON証跡に変換できます。ログ書式をスクリプトごとにばらばらにしないことが、変換スクリプトを増やさずに済ませるための設計判断です。

## 構築処理フロー（provision_web_server.sh）

`provision_web_server.sh --config FILE [--execute]` は次の順序で処理します。

1. 引数を解析する。`--config`は必須、`--execute`を付けなければドライラン（変更なしで予定だけ表示）です。
2. `load_config`で設定ファイルを読み込む。所有者と書込権限も確認します。
3. 必須項目（`PACKAGE_NAME` / `SERVICE_NAME` / `WEB_ROOT` / `SITE_TITLE`）が空でないか確認する。
4. `ALLOWED_TCP_PORTS`と`HTTP_PORT`が未設定なら既定値（`22 80`、`80`）を補う。
5. 値を検証する。`PACKAGE_NAME`・`SERVICE_NAME`は使用可能文字のみ、`WEB_ROOT`は絶対パスかつ危険なディレクトリでないこと、ポート番号は1〜65535の範囲であることを確認する。
6. `--execute`を指定したのにroot権限がない場合は終了コード2で拒否する。
7. 必要なコマンド（`apt-get` / `install` / `dpkg`）があるか確認する。
8. パッケージの導入状況をログに記録し、`apt-get update` / `apt-get install`を実行する（ドライランなら`[DRY-RUN]`表示のみ）。
9. サンプルページを作り、`WEB_ROOT/index.html`へ配置する。
10. `ufw`があれば`ALLOWED_TCP_PORTS`を許可して有効化する。なければ警告(WARN)を記録してスキップする。
11. `--execute`のときだけ`systemctl enable --now`でサービスを有効化・起動する。失敗または未対応の環境では警告(WARN)にとどめる。
12. `--execute`のときだけ、パッケージ導入と`index.html`の存在を自己確認する。失敗すれば終了コード2で停止する。
13. 警告が1件でもあれば終了コード1、なければ終了コード0で終わる。

## 冪等性の設計

冪等性とは、同じ処理を2回実行しても状態が壊れず、同じ結果に落ち着く性質です。`provision_web_server.sh`は次の理由で、2回実行しても安全です。

- `apt-get install`は導入済みのパッケージに対しては実質何もしません。
- `index.html`は毎回同じ内容で生成し、`install -D -m 0644`で安全に上書きします。中身が壊れた状態で止まることはありません。
- `ufw allow`は同じポートに対して重複して実行しても安全です。
- `systemctl enable --now`は、すでに有効化・起動済みのサービスに対しても安全に実行できます。

構築を何度実行しても意図しない変更が積み上がらないことは、[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)が「完成判定」に挙げている「自動化を2回実行し、2回目に意図しない変更がない」ことにつながります。

## 受け入れ試験フロー（build_verify.sh）

`build_verify.sh --config FILE [--output FILE]`は、構築後のサーバーが望ましい状態になっているかを次の5項目で確認します。`--output`を指定すると、画面表示と同時にファイルへもログを保存します。

| 確認項目 | OK条件 | WARN条件 |
|---|---|---|
| パッケージ導入 | `dpkg -s PACKAGE_NAME`が成功する | 失敗する |
| サービス稼働 | `systemctl is-active`が有効、または`pgrep`でプロセスが見つかる | どちらも見つからない |
| 配布ファイル | `WEB_ROOT/index.html`が存在し、サイズが0より大きい | 存在しない、または空 |
| HTTP応答 | `curl`で`http://127.0.0.1:HTTP_PORT + HEALTHCHECK_PATH`が200を返す | 200以外、または接続不可（`000`） |
| ファイアウォール許可 | `ufw`があり、`ufw status`に`HTTP_PORT/tcp`の許可がある | `ufw`がない、または許可を確認できない |

警告(WARN)が1件でもあれば終了コード1、すべてOKなら終了コード0です。設定ファイル自体が不正な場合は、この5項目を確認する前に終了コード2で停止します。

### 実際の出力例

検証環境で`nginx`を手動起動した状態で`build_verify.sh`を実行した、実際のログです（パスは`config/provision.conf.example`の既定値`/var/www/html`に置き換えています）。

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

このログを既存の`audit_report.py`でJSON証跡に変換できます。新しいPythonスクリプトを書く必要はありません。

```bash
./scripts/build_verify.sh --config config/provision.conf --output build-verify.log
python3 scripts/audit_report.py --input build-verify.log --output build-verify.json
```

```json
{
  "schema_version": 1,
  "source": "build-verify.log",
  "result": "WARN",
  "counts": {
    "INFO": 2,
    "OK": 4,
    "WARN": 2,
    "ERROR": 0
  },
  "entries": [
    { "timestamp": "2026-08-29T23:48:23+0000", "level": "OK", "message": "配布ファイルを確認しました: /var/www/html/index.html" }
  ]
}
```

（`entries`は実際には8件ありますが、紙面の都合で1件だけ抜粋しています。実物は[08. 検証証跡](08-evidence.md)の形式で記録してください。）

## 検証環境での確認結果

未実施や環境依存の内容を誇張しないよう、実際にコンテナ環境で確認できた事実だけを記します。

| 確認内容 | 結果 |
|---|---|
| ドライラン（`--execute`なし） | `[DRY-RUN]`表示のみで、何も変更されません（確認済み）。 |
| `--execute`実行 | nginxの導入と`/var/www/html/index.html`相当のサンプルページ配置までは成功します（確認済み）。 |
| `systemctl enable --now` | このコンテナ環境にはsystemdが動いていないため失敗し、警告（終了コード1）になります。実際のUbuntu VMではsystemdが動くため成功する想定です（検証環境に依存します）。 |
| ufwによるファイアウォール設定 | このコンテナ環境にはufwが入っていないため、警告（終了コード1）でスキップされます。実際のUbuntu VMではufwを導入して確認する想定です（検証環境に依存します）。 |
| nginxを手動起動した状態での`build_verify.sh` | パッケージ導入・サービス稼働・配布ファイル・HTTP応答の4項目はOK、ufw未導入の1件だけが警告として残り、終了コードは1です（確認済み）。 |
| 危険な設定の拒否 | `WEB_ROOT=/etc`、範囲外の`HTTP_PORT`、`PACKAGE_NAME`等の必須項目の記入漏れは、いずれも終了コード2で拒否されます（確認済み）。 |
| root権限のない`--execute` | 終了コード2で拒否されます（確認済み）。 |

自動テストとしては`tests/run_tests.sh`の「## 構築(provision_web_server.sh)のテスト」以降で、これらの正常系・異常系を再現できるようにしています。詳しいテスト方針は[05. テスト仕様](05-test-plan.md)を参照してください。

## セキュリティ設計

- `--execute`には常にroot権限を要求し、root以外なら終了コード2で拒否します（`sudoで実行してください`）。
- `WEB_ROOT`は絶対パスであることに加え、`/`や`/etc`など重要なシステムディレクトリそのものを`require_absolute_safe_path`で拒否します。
- `HTTP_PORT`と`ALLOWED_TCP_PORTS`の各値は、`require_integer_range`で1〜65535の整数であることを検証します。
- `PACKAGE_NAME`・`SERVICE_NAME`は許可した文字種の正規表現でのみ受け付け、任意のコマンドが混入しないようにします。
- 設定ファイルの所有者が実行ユーザーまたはrootであること、group/otherに書込権限がないことを`load_config`で確認します。
- コマンド引数は`--`と引用符で保護し、`eval`は使用しません。
- 既定の実行は常にドライランで、`--execute`を明示した場合だけ変更を行います。
- systemdやufwが存在しない環境では、致命的エラー（終了コード2）にはせず警告（終了コード1）にとどめます。検証環境依存であることを隠さず、警告として残すためです。実際のUbuntu VMではsystemd・ufwが利用できる前提で、この警告が出ないことを確認する必要があります。

## 残るリスク

この構築パックは[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)の「Phase 1: 手作業で仕組みを理解する」に対応する範囲です。次の観点は本パックの範囲外で、同ロードマップのPhase 2以降に委ねます。

- Ansibleなどの構成管理コードによる自動化と、初期VMからの再現。
- systemd timerやログ通知による継続的な監視。
- 簡易負荷試験や容量見積りなどの性能試験。
- Terraformなどによる検証環境そのものの作成（IaC）。

これらは「未実施」であり、実施したかのように書きません。着手する際は[10. サーバー構築ポートフォリオへの発展計画](10-server-build-roadmap.md)の優先度表を参照してください。
