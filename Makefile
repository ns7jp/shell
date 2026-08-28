SHELL := /usr/bin/env bash

.PHONY: help syntax test lint check

help:
	@printf '%s\n' 'make syntax  Bash構文を確認' 'make test    自己完結テストを実行' 'make lint    ShellCheckを実行（要インストール）' 'make check   syntaxとtestを実行'

syntax:
	@find scripts tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n

test: syntax
	@bash tests/run_tests.sh

lint:
	@command -v shellcheck >/dev/null || { echo 'shellcheck が必要です'; exit 2; }
	@shellcheck scripts/*.sh scripts/lib/*.sh tests/*.sh

check: syntax test
