SHELL := /usr/bin/env bash

.PHONY: help syntax test python-test lint check

help:
	@printf '%s\n' 'make syntax      Bash/Python構文を確認' 'make test        全自動テストを実行' 'make python-test Python単体テストを実行' 'make lint        ShellCheckを実行（要インストール）' 'make check       構文と全テストを実行'

syntax:
	@find scripts tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
	@python3 -m py_compile scripts/audit_report.py tests/test_audit_report.py

python-test:
	@python3 -m unittest discover -s tests -p 'test_*.py' -v

test: syntax python-test
	@bash tests/run_tests.sh

lint:
	@command -v shellcheck >/dev/null || { echo 'shellcheck が必要です'; exit 2; }
	@shellcheck scripts/*.sh scripts/lib/*.sh tests/*.sh

check: syntax test
