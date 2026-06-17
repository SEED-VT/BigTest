#!/usr/bin/env python3
"""Turn BigTest's generated test inputs (cvc5 models) into data files the Spark
jobs accept.

BigTest prints, per satisfiable JDU path, an SMT model with `define-fun` rows.
The top-level input rows are the variables named `input<N>` (the whole dataset
for a single-input job) and `input<N>_P<k>` (the individual records a
reduce/join path needs). The `input<N>_d<k>` variables are split-fragments of a
row and are NOT separate records, so they are excluded.

The `utils.TestSuite` harness reads each table from
    ./geninputs/<benchmark>/<pathId>/<category>/input<N>
via `sc.textFile(...).zipWithIndex().filter(_._2 > 0)` — i.e. it SKIPS the first
line as a header. This tool therefore writes a header line followed by one row
per generated record, in exactly that directory layout, so the produced files
are directly consumable by the benchmark jobs.

Usage:
    smt_to_data.py <mnemonic> [--runs-dir DIR] [--out DIR]
                              [--category primitive] [--num-inputs N]

By default it reads BigTest/runs/<mnemonic>/inputs.txt (produced by bigtest.sh)
and writes newbench/geninputs/<mnemonic>/path<k>/<category>/input<N>.
"""
import argparse
import os
import re
import sys

DEFINE_RE = re.compile(r'^\(define-fun\s+(\S+)\s*\(\)\s+String\s+(.*)\)\s*$')
# top-level input row: input<N> optionally with a _P<k> record suffix,
# but NOT a _d<k> split-fragment suffix.
ROW_RE = re.compile(r'^input(\d+)(?:_P(\d+))?$')


def unescape_smt_string(tok: str) -> str:
    """Parse an SMT-LIB 2.6 string literal token into its actual value."""
    tok = tok.strip()
    if len(tok) >= 2 and tok[0] == '"' and tok[-1] == '"':
        tok = tok[1:-1]
    # SMT-LIB escapes a double quote as "" and supports \u{...} / \uXXXX.
    tok = tok.replace('""', '"')
    tok = re.sub(r'\\u\{([0-9a-fA-F]+)\}', lambda m: chr(int(m.group(1), 16)), tok)
    tok = re.sub(r'\\u([0-9a-fA-F]{4})', lambda m: chr(int(m.group(1), 16)), tok)
    return tok


def parse_paths(lines):
    """Yield, per satisfiable path, a dict {table_index: [rows...]}."""
    paths = []
    cur_defs = None          # collected define-funs for the current cvc5 query
    verdict = None
    for line in lines:
        line = line.rstrip('\n')
        if line.startswith('cvc5 <') or line.startswith('running CVC'):
            # flush previous block
            if cur_defs is not None and verdict == 'sat':
                paths.append(cur_defs)
            cur_defs = {}
            verdict = None
            continue
        if cur_defs is None:
            continue
        if line.strip() in ('sat', 'unsat', 'unknown'):
            verdict = line.strip()
            continue
        m = DEFINE_RE.match(line.strip())
        if not m:
            continue
        name, value = m.group(1), m.group(2)
        rm = ROW_RE.match(name)
        if not rm:
            continue  # helper/fragment variable, skip
        table = int(rm.group(1))
        cur_defs.setdefault(table, []).append((name, unescape_smt_string(value)))
    if cur_defs is not None and verdict == 'sat':
        paths.append(cur_defs)
    return paths


def order_rows(rows):
    """Order records within a table: bare input<N> first, then _P1, _P2, ..."""
    def key(nv):
        name = nv[0]
        m = re.match(r'^input\d+(?:_P(\d+))?$', name)
        return int(m.group(1)) if (m and m.group(1)) else 0
    return [v for _, v in sorted(rows, key=key)]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('mnemonic')
    ap.add_argument('--runs-dir', default=None,
                    help='dir holding <mnemonic>/inputs.txt (default: BigTest/runs)')
    ap.add_argument('--out', default=None,
                    help='output base dir (default: newbench/geninputs)')
    ap.add_argument('--category', default='primitive',
                    help='category subdir TestSuite reads (primitive|refined)')
    ap.add_argument('--num-inputs', type=int, default=0,
                    help='number of input tables (default: auto-detect)')
    args = ap.parse_args()

    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    runs_dir = args.runs_dir or os.path.join(repo, 'BigTest', 'runs')
    out_base = args.out or os.path.join(repo, 'newbench', 'geninputs')

    src = os.path.join(runs_dir, args.mnemonic, 'inputs.txt')
    if not os.path.exists(src):
        alt = os.path.join(runs_dir, args.mnemonic, 'console.log')
        if os.path.exists(alt):
            src = alt
        else:
            sys.exit(f"error: no inputs.txt/console.log under {os.path.dirname(src)} "
                     f"(run `bigtest.sh {args.mnemonic}` first)")

    with open(src, encoding='utf-8', errors='replace') as f:
        # strip ANSI in case we're reading console.log
        lines = [re.sub(r'\x1b\[[0-9;]*[mK]', '', ln) for ln in f]

    paths = parse_paths(lines)
    if not paths:
        sys.exit(f"error: no satisfiable paths found in {src}")

    ntables = args.num_inputs or max((max(p) for p in paths if p), default=1)

    out_root = os.path.join(out_base, args.mnemonic)
    total_files = 0
    for i, tables in enumerate(paths, start=1):
        pdir = os.path.join(out_root, f"path{i}", args.category)
        os.makedirs(pdir, exist_ok=True)
        for t in range(1, ntables + 1):
            rows = order_rows(tables.get(t, []))
            fpath = os.path.join(pdir, f"input{t}")
            with open(fpath, 'w', encoding='utf-8') as out:
                # line 0 is skipped as a header by TestSuite.read()
                out.write(f"# bigtest {args.mnemonic} path{i} input{t} (header skipped)\n")
                for r in rows:
                    out.write(r + "\n")
            total_files += 1

    print(f"{args.mnemonic}: {len(paths)} satisfiable path(s), {ntables} input table(s)")
    print(f"  wrote {total_files} data file(s) under {out_root}/path*/{args.category}/")
    print(f"  layout: geninputs/{args.mnemonic}/path<k>/{args.category}/input<N>  "
          f"(consumed by utils.TestSuite)")


if __name__ == '__main__':
    main()
