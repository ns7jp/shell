#!/usr/bin/env python3
"""Bashのサーバー点検ログを、提出しやすいJSON証跡へ変換する。"""

from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
from collections import Counter
from datetime import datetime
from pathlib import Path

EXIT_OK = 0
EXIT_WARNING = 1
EXIT_ERROR = 2
LOG_PATTERN = re.compile(
    r"^(?P<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{4}) "
    r"\[(?P<level>INFO|OK|WARN|ERROR)] (?P<message>.+)$"
)


def parse_log(path: Path) -> dict[str, object]:
    """点検ログを読み、行と件数を辞書にまとめる。"""
    if not path.is_file():
        raise ValueError(f"入力ファイルが見つかりません: {path}")

    entries: list[dict[str, str]] = []
    for line_number, raw_line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if not raw_line.strip():
            continue
        match = LOG_PATTERN.fullmatch(raw_line)
        if match is None:
            raise ValueError(f"{line_number}行目を解析できません")
        item = match.groupdict()
        datetime.strptime(item["timestamp"], "%Y-%m-%dT%H:%M:%S%z")
        entries.append(item)

    if not entries:
        raise ValueError("入力ファイルに点検結果がありません")

    counts = Counter(entry["level"] for entry in entries)
    result = "ERROR" if counts["ERROR"] else "WARN" if counts["WARN"] else "OK"
    return {
        "schema_version": 1,
        "source": path.name,
        "result": result,
        "counts": {level: counts[level] for level in ("INFO", "OK", "WARN", "ERROR")},
        "entries": entries,
    }


def write_json(report: dict[str, object], output: Path) -> None:
    """途中までのJSONを残さないよう、同じディレクトリで作成後に置換する。"""
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=output.parent, prefix=f".{output.name}.", delete=False
    ) as temporary:
        json.dump(report, temporary, ensure_ascii=False, indent=2)
        temporary.write("\n")
        temporary_path = Path(temporary.name)
    temporary_path.replace(output)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="点検ログをJSON証跡へ変換します")
    parser.add_argument("--input", required=True, type=Path, help="server_audit.shの出力")
    parser.add_argument("--output", required=True, type=Path, help="作成するJSONファイル")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        report = parse_log(args.input)
        write_json(report, args.output)
    except (OSError, UnicodeError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return EXIT_ERROR

    print(f"JSON証跡を作成しました: {args.output}")
    return EXIT_WARNING if report["result"] == "WARN" else EXIT_ERROR if report["result"] == "ERROR" else EXIT_OK


if __name__ == "__main__":
    raise SystemExit(main())
