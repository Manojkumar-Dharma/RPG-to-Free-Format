#!/usr/bin/env python3
"""Generate rules/IACNVRULES_INSERT.sql from rules/IACNVRULES.sql and the JSON files.

IACNVRULES.sql loads the rule tables with JSON_TABLE, which older Db2 for i
levels do not have. This script writes the same tables as plain
INSERT ... VALUES statements, so the load works on any IBM i level.

Nothing is defined twice: the CREATE TABLE statements, the column names, the
column types and the JSON paths are all read from IACNVRULES.sql, the data
from the JSON files. The JSON files stay the source of truth.

Usage (run from anywhere; standard library only):
  python3 tools/GenRulesInsert.py            write rules/IACNVRULES_INSERT.sql
  python3 tools/GenRulesInsert.py --check    fail if the file is out of date

Run it after every change to a JSON file or to IACNVRULES.sql, and commit the
result together with the change.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RULES = ROOT / "rules"
SRC_SQL = RULES / "IACNVRULES.sql"
OUT_SQL = RULES / "IACNVRULES_INSERT.sql"

LINE_WIDTH = 90  # values are wrapped to this width, a value is never split

HEADER = """\
-- IACNVRULES_INSERT - creates and loads the rule tables of IACNVFREE with plain
-- INSERT statements. Same tables and same data as IACNVRULES.sql, for systems
-- without JSON_TABLE (older Db2 for i levels).
--
-- GENERATED FILE: do not edit. It is written by tools/GenRulesInsert.py from
-- IACNVRULES.sql and the JSON files of this directory. After changing a JSON
-- file, run the script again and commit both.
--
-- Run it (no path to change, the JSON files are not read):
--   RUNSQLSTM SRCSTMF('REPO/rules/IACNVRULES_INSERT.sql') COMMIT(*NONE)
--             NAMING(*SYS) DFTRDBCOL(MYLIB)
-- The tables are created in MYLIB (the DFTRDBCOL value); put MYLIB on the
-- library list so that IACNVFREE finds them. The file is UTF-8 (CCSID 1208)
-- and plain ASCII.
--
-- Do not run IACNVRULES.sql and this file into the same library: both create
-- the same tables, the last one run wins.
"""

# INSERT INTO <table> SELECT ... FROM JSON_TABLE(GET_CLOB_FROM_FILE(IARULESDIR
# CONCAT '<file>'), '$[*]' COLUMNS( <col> <type> PATH '$.<key>', ... )) AS J;
INSERT_RE = re.compile(
    r"INSERT INTO\s+(?P<table>\w+)\s+SELECT.*?"
    r"GET_CLOB_FROM_FILE\(IARULESDIR CONCAT '(?P<file>[^']+)'\),\s*"
    r"'\$\[\*\]'\s*COLUMNS\((?P<cols>.*?)\)\)\s*AS J;",
    re.DOTALL,
)
COL_RE = re.compile(
    r"(?P<name>\w+)\s+(?P<type>(?:VAR)?CHAR\(\d+\)|INTEGER)\s+"
    r"PATH\s+'\$\.(?P<key>\w+)'"
)


def fail(message):
    sys.exit("GenRulesInsert: " + message)


def sql_value(value, col, where):
    """Literal for one JSON value, checked against the column type."""
    if col["type"] == "INTEGER":
        if isinstance(value, bool) or not isinstance(value, int):
            fail(f"{where}: {col['key']} must be a whole number, got {value!r}")
        return str(value)
    if isinstance(value, bool) or not isinstance(value, (str, int)):
        fail(f"{where}: {col['key']} must be text, got {value!r}")
    text = str(value)
    if not text.isascii():
        fail(f"{where}: {col['key']} has a non-ASCII character: {text!r}")
    if len(text) > col["length"]:
        fail(f"{where}: {col['key']} is {len(text)} long, column {col['name']} "
             f"holds {col['length']}: {text!r}")
    return "'" + text.replace("'", "''") + "'"


def parse_columns(cols_text, table):
    columns = []
    for m in COL_RE.finditer(cols_text):
        length = re.search(r"\((\d+)\)", m["type"])
        columns.append({
            "name": m["name"],
            "type": "INTEGER" if m["type"] == "INTEGER" else "TEXT",
            "length": int(length[1]) if length else 0,
            "key": m["key"],
        })
    if not columns:
        fail(f"{table}: no columns found in the JSON_TABLE statement")
    return columns


def wrap_values(values, indent):
    """Lay the values of one row on lines of LINE_WIDTH at most."""
    lines, current = [], indent + "("
    for i, value in enumerate(values):
        piece = value + ("," if i < len(values) - 1 else ")")
        if current.strip("( ") and len(current) + 1 + len(piece) > LINE_WIDTH:
            lines.append(current.rstrip())
            current = indent + " "
        current += (" " if not current.endswith(("(", " ")) else "") + piece
    lines.append(current)
    return lines


def wrap_names(prefix, names):
    """Lay a column list on lines of LINE_WIDTH at most."""
    lines, current = [], prefix
    for i, name in enumerate(names):
        piece = name + ("," if i < len(names) - 1 else ")")
        if len(current) + 1 + len(piece) > LINE_WIDTH and current != prefix:
            lines.append(current.rstrip())
            current = "    "
        current += ("" if current in (prefix, "    ") else " ") + piece
    lines.append(current)
    return lines


def build_insert(table, json_file, columns):
    path = RULES / json_file
    try:
        rows = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as err:
        fail(f"{json_file}: cannot be read as JSON: {err}")
    if not isinstance(rows, list) or not rows:
        fail(f"{json_file}: must be a JSON array with at least one row")
    names = [c["name"] for c in columns]
    head = f"INSERT INTO {table} ({', '.join(names)}) VALUES"
    if len(head) > LINE_WIDTH:
        head = "\n".join(wrap_names(f"INSERT INTO {table} (", names)) + " VALUES"
    out = [head]
    for number, row in enumerate(rows, 1):
        where = f"{json_file} row {number}"
        values = []
        for col in columns:
            if col["key"] not in row:
                fail(f"{where}: key '{col['key']}' is missing")
            values.append(sql_value(row[col["key"]], col, where))
        row_lines = wrap_values(values, "  ")
        row_lines[-1] += ";" if number == len(rows) else ","
        out.extend(row_lines)
    return "\n".join(out) + "\n"


def generate():
    source = SRC_SQL.read_text(encoding="utf-8")
    body_start = source.index("CREATE OR REPLACE TABLE IACNVOPC")
    # Keep the comment lines that sit above the first table (its description).
    comment_start = body_start
    while True:
        previous = source.rfind("\n", 0, comment_start - 1) + 1
        if not source[previous:comment_start].startswith("--"):
            break
        comment_start = previous
    body = source[comment_start:]

    seen = 0

    def replace(match):
        nonlocal seen
        seen += 1
        columns = parse_columns(match["cols"], match["table"])
        return build_insert(match["table"], match["file"], columns).rstrip("\n")

    body = INSERT_RE.sub(replace, body)
    if seen == 0:
        fail("no INSERT ... JSON_TABLE statement found in IACNVRULES.sql")
    if "JSON_TABLE" in body or "IARULESDIR" in body:
        fail("a JSON_TABLE statement was not converted; check IACNVRULES.sql")
    return HEADER + "\n" + body


def main():
    text = generate()
    if "--check" in sys.argv[1:]:
        current = OUT_SQL.read_text(encoding="utf-8") if OUT_SQL.exists() else ""
        if current != text:
            fail(f"{OUT_SQL.relative_to(ROOT)} is out of date: run "
                 "python3 tools/GenRulesInsert.py and commit the result")
        print("rules/IACNVRULES_INSERT.sql is up to date")
        return
    OUT_SQL.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT_SQL.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
