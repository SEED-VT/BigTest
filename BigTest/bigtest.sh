# $1: target program mnemonic, full path defined in init
# $2: optional, filepath to record runtime stats
#
# The engine writes its working artifacts to $BigTest/Rundir/ (decompiled .jad,
# extracted UDF .java/.class/.jpf, and one .smt2 per satisfiable JDU path), and
# prints the concrete test inputs (cvc5 models) to the console. Rundir is wiped
# on every run, so after each run we ARCHIVE everything to a per-benchmark folder
# $BigTest/runs/<mnemonic>/ that is NOT overwritten by other benchmarks.
pushd `dirname ${BASH_SOURCE[0]}` >/dev/null
source init.sh
mkdir -p $BigTest/Rundir

bigtest() {
    local mnemonic="$1"
    local stats="$2"
    local archive="$BigTest/runs/$mnemonic"

    rm -f $BigTest/Rundir/* 2>/dev/null
    rm -rf "$archive"; mkdir -p "$archive"

    # Run BigTest, mirroring the console (which carries the generated test inputs)
    # into the archive while still showing it live.
    java -ea -cp "$dependencies" gov.nasa.jpf.JPF -enableBT ${binpath[$mnemonic]} $stats 2>&1 \
        | tee "$archive/console.log"

    # Engine artifacts (.jad/.java/.class/.jpf/.smt2) for this run.
    cp -f $BigTest/Rundir/* "$archive/" 2>/dev/null

    # Distilled, ANSI-stripped view of the generated test inputs and the per-path
    # solver verdicts, in run order.
    sed -E 's/\x1B\[[0-9;]*[mK]//g' "$archive/console.log" \
        | grep -E '^\(define-fun|^sat$|^unsat$|^Path |^cvc5 <|#Valid paths|Total .* Time' \
        > "$archive/inputs.txt" 2>/dev/null

    # Also materialize job-ready data files (newbench/geninputs/<mnemonic>/path*/...)
    # so a plain `run` leaves directly-runnable test inputs behind. Skipped if
    # python3 is unavailable or no satisfiable paths were produced.
    local converter="$BigTest/../tools/smt_to_data.py"
    if command -v python3 >/dev/null 2>&1 && [ -f "$converter" ]; then
        python3 "$converter" "$mnemonic" 2>/dev/null \
            && echo "  geninputs    -> newbench/geninputs/$mnemonic/path*/primitive/input*" \
            || echo "  (no data files: no satisfiable paths)"
    fi

    echo ""
    echo "Outputs archived to: $archive"
    echo "  console.log  full run log"
    echo "  inputs.txt   generated test inputs + per-path verdicts"
    echo "  *.jad/.java/.jpf/.smt2  engine artifacts for this run"
    #read -n1 -r -p ""
}
bigtest $1 $2
popd >/dev/null
