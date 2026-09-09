# 52. 変更管理・復旧ハンズオン

この章は[検証環境の構築](03-setup.md)で用意したUbuntu VM（検証環境）がすでにある前提で進めます。対象は「変更前の状態を保存する」`scripts/snapshot_config.sh`、「変更を適用し、失敗したら自動で戻す」`scripts/change_deploy.sh`、「スナップショットから戻す」`scripts/restore_config.sh`の3本です。[42. セキュリティ強化ハンズオン](42-security-hands-on.md)と同じ演習形式で、1つずつ実際に手を動かします。

## この章の前提

- 設定キーと切戻し基準の意味は先に[51. 変更管理・復旧の基本設計](51-change-design.md)を確認してください。
- **`--execute`は必ず使い捨ての検証用VMやコンテナで行い、本番サーバーや共有マシン、日常使っている端末では絶対に実行しないでください。**
- 終了コードの意味は他パックと共通です。

| 終了コード | 意味 |
|---:|---|
| 0 | 正常（`EXIT_OK`、警告なし） |
| 1 | 警告あり（`EXIT_WARNING`。検証ゲートの結果次第では、変更は維持されたまま） |
| 2 | 実行エラー（`EXIT_ERROR`。設定不備・危険な値の拒否・検証ゲート不合格による自動切戻しを含む） |

## 演習1: 学習用の対象ディレクトリを用意する

実システムを壊さずに一連の流れを体験するため、まずは自分のホームディレクトリ配下に「変更対象」と「変更元」を用意します（これは実際のUbuntu VMでも、検証用のこのコンテナでも同じ手順で行えます）。

```bash
mkdir -p ~/change-lab/target ~/change-lab/source-v2
printf '<!doctype html><title>旧バージョン</title>\n' > ~/change-lab/target/index.html
printf '<!doctype html><title>新バージョン</title>\n' > ~/change-lab/source-v2/index.html

cp config/change.conf.example ~/change-lab/change.conf
sed -i "s|^SNAPSHOT_DIR=.*|SNAPSHOT_DIR=$HOME/change-lab/snapshots|" ~/change-lab/change.conf
sed -i "s|^SNAPSHOT_TARGETS=.*|SNAPSHOT_TARGETS=\"$HOME/change-lab/target\"|" ~/change-lab/change.conf
sed -i "s|^CHANGE_TARGET=.*|CHANGE_TARGET=$HOME/change-lab/target|" ~/change-lab/change.conf
sed -i "s|^VERIFY_CMD=.*|VERIFY_CMD=\"true\"|" ~/change-lab/change.conf
chmod 600 ~/change-lab/change.conf
```

`VERIFY_CMD=true`はまず「検証ゲートが必ず合格する」状態で流れを確認するための仮の設定です。演習3で実際の検証ゲート（`build_verify.sh`）に差し替えます。

## 演習2: スナップショットを作る

```bash
./scripts/snapshot_config.sh --config ~/change-lab/change.conf --label demo
```

`--execute`を付けなければドライランです。何も作成されず、実行予定のコマンドだけが表示されます。

```bash
./scripts/snapshot_config.sh --config ~/change-lab/change.conf --label demo --execute
```

期待: `~/change-lab/snapshots/demo_<タイムスタンプ>/`が作成され、`payload/`配下に対象ディレクトリのコピー、`manifest.txt`にチェックサムが記録されます。ログの最後に`SNAPSHOT_PATH=...`という行が出力されます。これは`change_deploy.sh`が内部で自動的に読み取る行で、手動で呼ぶ場合も切戻し先の指定に使えます。

```bash
cat ~/change-lab/snapshots/demo_*/manifest.txt
```

## 演習3: 変更を適用し、検証ゲートに合格させる

```bash
./scripts/change_deploy.sh --config ~/change-lab/change.conf --source ~/change-lab/source-v2 --execute
echo "終了コード=$?"
cat ~/change-lab/target/index.html
```

期待: 1) 変更前スナップショットが自動的に作られる、2) `~/change-lab/target/index.html`が「新バージョン」に置き換わる、3) `VERIFY_CMD=true`が終了コード0を返すため「検証ゲートに合格しました」と表示され、終了コードが0になる。

## 演習4: 検証ゲートを実際のNginx受け入れ試験に差し替える

`config/provision.conf.example`と同じ`WEB_ROOT`を`CHANGE_TARGET`に合わせたうえで、`VERIFY_CMD`を`build_verify.sh`に差し替えます（この演習は、実際にNginxが導入済みの検証VMで行います。この検証環境のようにNginxが未導入の場合は、`build_verify.sh`が警告付き終了コード1を返すことを確認するだけでも学習になります）。

```bash
sed -i "s|^VERIFY_CMD=.*|VERIFY_CMD=\"bash $(pwd)/scripts/build_verify.sh --config $(pwd)/config/provision.conf.example\"|" ~/change-lab/change.conf
./scripts/change_deploy.sh --config ~/change-lab/change.conf --source ~/change-lab/source-v2 --execute
echo "終了コード=$?"
```

期待（この検証環境のようにNginx未導入の場合）: `build_verify.sh`がパッケージ未導入・サービス未確認等でWARNを複数記録し、終了コード1で戻ります。`change_deploy.sh`はこれを「警告あり、人による判断が必要」と扱い、**自動切戻しはせず**変更を維持したまま終了コード1で終わります。

## 演習5: わざと検証ゲートを失敗させ、自動切戻しを確認する

```bash
sed -i "s|^VERIFY_CMD=.*|VERIFY_CMD=\"exit 2\"|" ~/change-lab/change.conf
printf '<!doctype html><title>切戻し前の内容</title>\n' > ~/change-lab/target/index.html
./scripts/change_deploy.sh --config ~/change-lab/change.conf --source ~/change-lab/source-v2 --execute
echo "終了コード=$?"
cat ~/change-lab/target/index.html
```

期待: `VERIFY_CMD`が終了コード2を返すため、「検証ゲートが失敗しました...自動的にスナップショットへ切戻します」と表示され、`restore_config.sh`が自動的に呼び出されます。復元後、`~/change-lab/target/index.html`の内容は「切戻し前の内容」（＝直前のスナップショット時点の内容）に戻ります。終了コードは2（`EXIT_ERROR`）です。ログの末尾に「スナップショット時点と一致しました」という行があることを確認してください。これが復元試験（cpの成功だけでなく、チェックサムで一致を証明する）にあたります。

## 演習6: 単独で復元する

`change_deploy.sh`を使わず、`snapshot_config.sh`と`restore_config.sh`だけを手動で組み合わせることもできます。

```bash
./scripts/snapshot_config.sh --config ~/change-lab/change.conf --label manual --execute
snap=$(ls -dt ~/change-lab/snapshots/manual_* | head -n1)
printf '<!doctype html><title>手動で書き換えた内容</title>\n' > ~/change-lab/target/index.html
./scripts/restore_config.sh --config ~/change-lab/change.conf --snapshot "$snap" --execute
cat ~/change-lab/target/index.html
```

期待: `manual`ラベルのスナップショット時点（書き換え前）の内容に戻り、復元後の差分確認で「すべて一致しました」と表示されます。

## わざと失敗させる（入力検証）

```bash
cp ~/change-lab/change.conf ~/change-lab/change_danger.conf
sed -i 's|^SNAPSHOT_DIR=.*|SNAPSHOT_DIR=/etc|' ~/change-lab/change_danger.conf
./scripts/snapshot_config.sh --config ~/change-lab/change_danger.conf --label x
echo "終了コード=$?"
```

期待: 「`SNAPSHOT_DIR に重要なシステムディレクトリそのものは指定できません`」というメッセージとともに、終了コード2で拒否されます。

```bash
cp ~/change-lab/change.conf ~/change-lab/change_no_target.conf
sed -i 's|^SNAPSHOT_TARGETS=.*|SNAPSHOT_TARGETS="/tmp/somewhere-else"|' ~/change-lab/change_no_target.conf
./scripts/change_deploy.sh --config ~/change-lab/change_no_target.conf --source ~/change-lab/source-v2
echo "終了コード=$?"
```

期待: 「`SNAPSHOT_TARGETS に CHANGE_TARGET を含めてください（変更対象を切戻せなくなります）`」というメッセージとともに、終了コード2で拒否されます（`--execute`を付けていなくても、この検証は行われます）。

## 覚え方

[用語集・チートシート](09-glossary-cheatsheet.md)にある「受ける・疑う・動かす・確かめる・伝える」の5段階は、変更管理・復旧でも同じ順で使います。

1. **受ける:** `--config`と`--source`（または`--snapshot`）で入力を受け取ります。
2. **疑う:** `SNAPSHOT_DIR`・`SNAPSHOT_TARGETS`・`CHANGE_TARGET`の安全性、`CHANGE_TARGET`が`SNAPSHOT_TARGETS`に含まれているかを検証し、危険な値は終了コード2で拒否します。
3. **動かす:** 必ずスナップショットを取ってから変更を適用します。ドライランで内容を確認してから、検証用VMやコンテナだけで`--execute`を動かします。
4. **確かめる:** 検証ゲート（`VERIFY_CMD`）の終了コードでgo/no-goを判定し、不合格なら自動的に`restore_config.sh`を呼び出し、復元後にチェックサムで一致を確認します。
5. **伝える:** ログと終了コード、切戻し基準表（[51. 変更管理・復旧の基本設計](51-change-design.md)）、変更ウィンドウと承認記録（[50. 変更管理・復旧案件概要](50-change-project-overview.md)）で結果を伝えます。
