# Bash演習案件パック

未経験からサーバー構築エンジニアを目指す人が、このリポジトリの中身を **手を動かして** 身につけるための演習21問です。読むだけで終わらないよう、結果は採点ツールが機械的に判定します。

詳しい案内は [docs/15-exercise-pack-guide.md](../docs/15-exercise-pack-guide.md) を読んでください。

## まず覚える3つ

```bash
bash exercises/labctl.sh init      # 作業場($HOME/bash-lab)を作り、環境を点検します
bash exercises/labctl.sh show E01  # 問題文を表示します
bash exercises/labctl.sh grade E01 # 採点します（0=合格 1=不合格 2=実行エラー）
```

そのほかのコマンドは `bash exercises/labctl.sh --help` で一覧できます。

## 覚える量

| # | 覚えるもの | 実数 |
|---:|---|---:|
| 1 | 5語スパイン（受ける・疑う・動かす・確かめる・伝える） | 5語 |
| 2 | 骨9要素 | 9要素 |
| 3 | 暗記カード | 17枚 |

これ以上は増やしません。1枚にまとめたものが [docs/17-memory-cheatsheet.md](../docs/17-memory-cheatsheet.md) です。

## 安全について

- **root権限もネットワークも使いません。** `sudo` や `apt-get` を実行させる演習はひとつもありません。
- 書き込むのは `$HOME/bash-lab` と、採点ごとに作る使い捨てディレクトリだけです。
- 採点は答案を複製してから実行します。元のファイルは変更しません。
- すべての実行に時間制限が付きます。

## ディレクトリ構成

```text
labctl.sh          学習者が打つ唯一のコマンド
exercises.tsv      21問の一覧（唯一の情報源）
levels/Lx/         問題文とヒント
checks/            1問1本の採点スクリプト
answers/           模範解答
answers/wrong/     誤答例（採点器が常に合格を返す欠陥を防ぐため）
templates/         写経・穴埋めの雛形（.tmpl）
fixtures/          採点用の教材
cards/cards.tsv    暗記カード17枚
lib/               共通処理と判定プリミティブ
tests/             採点ツール自身のテスト
```

採点の仕組みは [docs/16-exercise-grading-design.md](../docs/16-exercise-grading-design.md) にまとめています。

## 開発者向け

```bash
make lab-lint        # 演習パックのShellCheck
make lab-selfcheck   # 模範解答で合格・誤答で不合格の両方を検証
make lab-grade       # 自分の答案を全問採点
```
