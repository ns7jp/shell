# 03. 検証環境の構築

## 推奨環境

- Ubuntu 22.04または24.04のVM
- CPU 2、メモリ2GB、空きディスク10GB程度
- NATネットワーク（外部公開しない）
- Git、Bash、Python 3.10以上、Make、tar、gzip、findutils

## セットアップ

```bash
sudo apt update
sudo apt install -y git make shellcheck python3
git clone https://github.com/ns7jp/shell.git
cd shell
chmod +x scripts/*.sh tests/run_tests.sh
make check
```

`bash --version` と `python3 --version` を証跡へ記録します。追加Pythonパッケージは使わないため、`pip install` は不要です。

## 安全な練習データ

本物の `/srv` や `/var` の代わりに、自分のホーム配下を使います。

```bash
mkdir -p "$HOME/shell-lab/source" "$HOME/shell-lab/backups"
printf 'hello backup\n' > "$HOME/shell-lab/source/sample.txt"
cp config/backup.conf.example config/backup.conf
sed -i "s|^SOURCE_DIR=.*|SOURCE_DIR=$HOME/shell-lab/source|" config/backup.conf
sed -i "s|^BACKUP_DIR=.*|BACKUP_DIR=$HOME/shell-lab/backups|" config/backup.conf
chmod 600 config/backup.conf
./scripts/backup.sh --config config/backup.conf
```

表示されたコマンドとパスが意図どおりの場合だけ、検証環境で `--execute` を付けます。

```bash
./scripts/backup.sh --config config/backup.conf --execute
find "$HOME/shell-lab/backups" -maxdepth 1 -type f -ls
```

## ロールバック

練習データだけを対象にしたことを `pwd` と `realpath "$HOME/shell-lab"` で再確認してから、不要な場合はその専用ディレクトリを削除します。リポジトリやホーム全体を削除対象にしないでください。
