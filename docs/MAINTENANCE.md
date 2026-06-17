# Maintenance log — getting BigTest building & running again

This records the work to make the 2019/2020 artifact compatible, building, and
running, plus the engine repairs found along the way.

## Environment findings

- The whole JVM stack (both `jpf-core` + `jpf-symbc` trees, `SymExec`,
  `UDFExtractor`) **compiles on any JDK 8 + Scala 2.11 host**, including macOS.
- The bundled native dependencies — `dependencies/cvc5`, `dependencies/jad`, and
  the bundled JDK — are **Linux x86 ELF binaries**. They cannot execute on macOS
  (Apple Silicon or Intel). This is the only true portability blocker.
- Resolution: a `linux/amd64` Docker image (`docker/Dockerfile`,
  `docker/bigtest-docker.sh`) that supplies the missing build tooling (`ant`,
  `python3`, 32-bit loader for `jad`) and bind-mounts the repo so the bundled
  JDK/Scala/Spark/cvc5/jad are used verbatim. Validated under Rosetta/qemu on
  Apple Silicon: cvc5 1.0.5, jad 1.5.8e, OpenJDK 8u352 all run.

## Build/script repairs

- `BigTest/SymExec/.../PathEffectListenerImp.scala`: the "Java path:" log printed
  a hardcoded `/mnt/ssd/thaddywu/...` path. Now uses `System.getenv("BigTest")`
  (the same resolution the real file writes already use).
- `BigTest/BenchmarksFault/compile.sh`: was stale (referenced a nonexistent
  `src/movie/`, never created `bin/`). Rewritten to `mkdir bin` and compile the
  whole suite (`src/**/*.scala`, target `jvm-1.5` for jad compatibility).
- `BigTest/BenchmarksFault/src/credit/credit.scala`: used Java-style array
  indexing `split(",")[0]` (a syntax error in Scala) and an always-false
  `Array.equals("bad")` filter. Fixed to `(0)`/`(n)` indexing and a column-indexed
  filter.
- `BigTest/init.sh`: the `wordcount` benchmark path pointed at
  `pigmixl2/wordcount/WordCount$`; corrected to `wordcount/WordCount$`.

## Engine repairs (correctness)

These were uncovered by the paper demos and fixed in `SymExec`:

1. **`String.startsWith` was unsupported.** The `ComparisonOp` enum lacked
   `startswith`/`notstartswith`, so any program using `.startsWith(...)` crashed
   with `NoSuchElementException: No value found for 'notstartswith'`. Added both
   operators (`Constraint.scala`) and an SMT encoding to `str.prefixof`
   (`x.startsWith(p)` ⇒ `(str.prefixof p x)`, with the negated form wrapped in
   `not`). Required by the ICSE 2020 `gradebook` demo.

2. **Integer division emitted the wrong SMT symbol.** `NonTerminal.toZ3Query`
   printed the Scala operator `/`, which cvc5 rejects in the integer/string logic
   (`Symbol '/' not declared as a variable`). Added `SymOp.toSMT`, mapping
   `Division` to SMT-LIB `div` (others unchanged). Required by the FSE 2019
   `commutetrips` demo (`dist.toInt / time.toInt`).

## Verification

Under the Docker environment, all of the following build and generate test
inputs (no fatal errors):

- **newbench (13):** movie1, transit, credit, airport, usedcars,
  Q1, Q3, Q6, Q7, Q12, Q15, Q19, Q20.
- **paper demos (2):** gradebook (ICSE 2020), commutetrips (FSE 2019).
- **BenchmarksFault (6):** wordcount, movieratings, income, StudentGrades,
  commute, l2.

`#Valid paths` per program ranged from 2 to 32; per-program test generation took
roughly 10–55 s under emulation.

## Known follow-ups

- Some TPC-DS programs (Q12/Q15/Q20) print solver "error" lines for infeasible
  paths; these are `unsat` paths (expected) plus cvc5's "Cannot get model" notice
  after `unsat`, not tool failures.
- `jad` warns "class file version 49.0 … only … 47.0 supported" but still
  decompiles; benchmarks are compiled `-target:jvm-1.5` to minimize this.
- Modernization toward a current JDK / Scala 2.13 / Spark 3 / upstream cvc5 is a
  larger, separate effort (the JPF/SPF fork is the constraining piece).
