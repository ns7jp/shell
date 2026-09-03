SHELL := /usr/bin/env bash

.PHONY: help syntax test python-test lint check lab-lint lab-selfcheck lab-grade

help:
	@printf '%s\n' 'make syntax      Bash/Python構文を確認' 'make test        全自動テストを実行' 'make python-test Python単体テストを実行' 'make lint        ShellCheckを実行（要インストール）' 'make check       構文と全テストを実行' 'make lab-lint    演習パックのShellCheckを実行' 'make lab-selfcheck 演習パックの採点器を自己検査' 'make lab-grade   自分の答案を全問採点'

syntax:
	@find scripts tests exercises -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
	@python3 -m py_compile scripts/audit_report.py tests/test_audit_report.py

python-test:
	@python3 -m unittest discover -s tests -p 'test_*.py' -v

test: syntax python-test
	@bash tests/run_tests.sh

lint:
	@command -v shellcheck >/dev/null || { echo 'shellcheck が必要です'; exit 2; }
	@shellcheck scripts/*.sh scripts/lib/*.sh tests/*.sh

# 演習パックは本体パックのCIを壊さないよう、別ターゲットに分けています。
# SC1090/SC1091 は source 先を追えないという道具側の制限のため除外します。
lab-lint:
	@command -v shellcheck >/dev/null || { echo 'shellcheck が必要です'; exit 2; }
	@shellcheck -e SC1090,SC1091 exercises/labctl.sh exercises/lib/*.sh exercises/checks/*.sh exercises/answers/*.sh exercises/fixtures/*.sh exercises/tests/*.sh

lab-selfcheck:
	@bash exercises/labctl.sh selfcheck
	@bash exercises/tests/test_labctl.sh

lab-grade:
	@bash exercises/labctl.sh grade --all

check: syntax test
