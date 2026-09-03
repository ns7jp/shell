SHELL := /usr/bin/env bash

.PHONY: help syntax test python-test lint check lab-lint lab-selfcheck lab-grade ps-syntax ps-test ps-lint check-all

help:
	@printf '%s\n' 'make syntax      Bash/Python構文を確認' 'make test        全自動テストを実行' 'make python-test Python単体テストを実行' 'make lint        ShellCheckを実行（要インストール）' 'make check       構文と全テストを実行' 'make lab-lint    Bash演習パックのShellCheckを実行' 'make lab-selfcheck Bash演習パックの採点器を自己検査' 'make lab-grade   自分の答案を全問採点' 'make ps-syntax   PowerShell構文を確認（要pwsh）' 'make ps-test     PowerShell自動テストを実行（要pwsh）' 'make ps-lint     PSScriptAnalyzerを実行（要pwsh・要インストール）' 'make check-all   Bash/Python/PowerShellをまとめて実行'

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

## PowerShell演習案件パック -----------------------------------------------
## pwsh (PowerShell 7以上) が必要です。未導入の環境では実行できない旨を表示して止まります。
ps-syntax:
	@command -v pwsh >/dev/null || { echo 'pwsh (PowerShell 7以上) が必要です'; exit 2; }
	@pwsh -NoProfile -Command '$$total = 0; foreach ($$file in Get-ChildItem scripts/powershell, tests/powershell -Recurse -Include *.ps1,*.psm1) { $$errors = $$null; $$tokens = $$null; [System.Management.Automation.Language.Parser]::ParseFile($$file.FullName, [ref]$$tokens, [ref]$$errors) | Out-Null; if ($$errors.Count -gt 0) { $$total += $$errors.Count; Write-Output ("{0}: {1}件の構文エラー" -f $$file.Name, $$errors.Count) } }; if ($$total -gt 0) { exit 2 }; Write-Output "PowerShell構文エラーなし"'

ps-test: ps-syntax
	@pwsh -NoProfile -File tests/powershell/Run-PowerShellTests.ps1

ps-lint:
	@command -v pwsh >/dev/null || { echo 'pwsh (PowerShell 7以上) が必要です'; exit 2; }
	@pwsh -NoProfile -Command 'if (-not (Get-Module PSScriptAnalyzer -ListAvailable)) { Write-Output "PSScriptAnalyzer が必要です: Install-Module PSScriptAnalyzer -Scope CurrentUser"; exit 2 }; $$found = Invoke-ScriptAnalyzer -Path scripts/powershell -Recurse -Settings ./PSScriptAnalyzerSettings.psd1; $$found += Invoke-ScriptAnalyzer -Path tests/powershell -Recurse -Settings ./PSScriptAnalyzerSettings.psd1; if ($$found) { $$found | Format-Table -AutoSize | Out-String | Write-Output; exit 2 }; Write-Output "PSScriptAnalyzer の指摘なし"'

check-all: check ps-test
