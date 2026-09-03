SHELL := /usr/bin/env bash

.PHONY: help syntax test python-test lint check ps-syntax ps-test ps-lint check-all

help:
	@printf '%s\n' 'make syntax      Bash/Python構文を確認' 'make test        全自動テストを実行' 'make python-test Python単体テストを実行' 'make lint        ShellCheckを実行（要インストール）' 'make check       構文と全テストを実行' 'make ps-syntax   PowerShell構文を確認（要pwsh）' 'make ps-test     PowerShell自動テストを実行（要pwsh）' 'make ps-lint     PSScriptAnalyzerを実行（要pwsh・要インストール）' 'make check-all   Bash/Python/PowerShellをまとめて実行'

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

## PowerShell演習案件パック -----------------------------------------------
## pwsh (PowerShell 7以上) が必要です。未導入の環境では実行できない旨を表示して止まります。
ps-syntax:
	@command -v pwsh >/dev/null || { echo 'pwsh (PowerShell 7以上) が必要です'; exit 2; }
	@pwsh -NoProfile -Command '$$total = 0; foreach ($$file in Get-ChildItem scripts/powershell, tests/powershell -Recurse -Include *.ps1,*.psm1) { $$errors = $$null; $$tokens = $$null; [System.Management.Automation.Language.Parser]::ParseFile($$file.FullName, [ref]$$tokens, [ref]$$errors) | Out-Null; if ($$errors.Count -gt 0) { $$total += $$errors.Count; Write-Output ("{0}: {1}件の構文エラー" -f $$file.Name, $$errors.Count) } }; if ($$total -gt 0) { exit 2 }; Write-Output "PowerShell構文エラーなし"'

ps-test: ps-syntax
	@pwsh -NoProfile -File tests/powershell/Run-PowerShellTests.ps1

ps-lint:
	@command -v pwsh >/dev/null || { echo 'pwsh (PowerShell 7以上) が必要です'; exit 2; }
	@pwsh -NoProfile -Command 'if (-not (Get-Module PSScriptAnalyzer -ListAvailable)) { Write-Output "PSScriptAnalyzer が必要です: Install-Module PSScriptAnalyzer -Scope CurrentUser"; exit 2 }; $$found = Invoke-ScriptAnalyzer -Path scripts/powershell -Recurse -Severity Error,Warning; $$found += Invoke-ScriptAnalyzer -Path tests/powershell -Recurse -Severity Error,Warning; if ($$found) { $$found | Format-Table -AutoSize | Out-String | Write-Output; exit 2 }; Write-Output "PSScriptAnalyzer の指摘なし"'

check-all: check ps-test
