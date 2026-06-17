# Modernization roadmap

The artifact is **fully working** on its original stack
(JDK 8 / Scala 2.11.12 / Spark 2.4 / cvc5 1.0.5) inside the `linux/amd64` Docker
environment. This document lays out a staged path to newer toolchains and is
honest about what is safe vs. what is hard. **Do each stage on a branch and keep
the Docker baseline green as the regression oracle** (the per-benchmark
`#Valid paths` counts in [MAINTENANCE.md](MAINTENANCE.md)).

## Status

| stage | what | status |
|-------|------|--------|
| 1 | Pluggable solver (`BIGTEST_SOLVER`) | **done & verified** |
| 4 | Replace `jad` with CFR (`BIGTEST_DECOMPILER=cfr`) | **done & validated: matches jad on all 18 benchmarks** |
| 2 | Benchmarks → Spark 3 / Scala 2.12 | not started (now unblocked by 4) |
| 3 | JPF/SPF → JDK 11/17 | not started (large) |

The default path (jad + bundled cvc5) is untouched and green; the changes above
are additive and guarded by environment variables.

## The constraining component

The hard dependency is the **customized Java PathFinder / Symbolic PathFinder
fork** (`jpf-core`, `jpf-symbc`). It is pinned to JDK 8 in deep ways:

- It ships modeled JDK classes (`src/classes/java/lang/String.java`,
  `System.java`, `sun/misc/SharedSecrets.java`) that mirror **Java 8** internals.
- It reads/instruments bytecode up to class version 52 (Java 8); `jad` reads
  ≤ 49 (hence benchmarks compile `-target:jvm-1.5`).
- It relies on `sun.misc.*` APIs removed/relocated in JDK 9+.

Everything else (SymExec, UDFExtractor, the benchmarks) is comparatively easy to
move. So the JPF fork dictates the order below.

## Stage 1 — Solver (DONE) ✅

The SMT we emit is standard **SMT-LIB 2.6**: `QF_ASNIA` + strings, using only
portable operators (`str.prefixof`, `str.in_re`, `str.to_int`, `str.from_int`,
`div`, `str.++`, `str.substr`). Nothing is cvc5-1.0.5-specific.

**Done:** the solver invocation is now configurable via the `BIGTEST_SOLVER`
environment variable (`PathEffect.invokeSMT`), defaulting to the bundled `cvc5`.
The SMT2 query is fed on stdin, so any solver works:

```bash
BIGTEST_SOLVER="cvc5 --strings-exp --lang smt2"   # a newer cvc5 on a real Linux box
BIGTEST_SOLVER="z3 -in -smt2"                      # Z3
```

Verified: a logging wrapper set via `BIGTEST_SOLVER` is invoked once per path and
yields identical `#Valid paths`.

**Emulation caveat (Apple Silicon only):** newer cvc5 release binaries (≥1.1)
abort with *Illegal instruction* under Rosetta/qemu `linux/amd64` emulation
(they target a newer x86 ISA baseline). The bundled cvc5 1.0.5 was built for an
older baseline and runs. On a **real x86-64 Linux** host this is a non-issue —
point `BIGTEST_SOLVER` at any current cvc5/Z3.

## Stage 2 — Benchmarks to Spark 3 / Scala 2.12–2.13 (medium risk)

Key insight: **BigTest never runs Spark.** It decompiles the benchmark bytecode
and symbolically executes the UDFs. Spark jars are only a *compile-time* API for
the benchmark programs. So benchmarks can move to Spark 3 / newer Scala
independently of the JPF runtime, as long as:

- UDF bytecode stays decompilable by `jad` (keep `-target` low, or replace `jad`
  — see Stage 4).
- The `UDFExtractor` AST visitor (`SparkProgramVisitor`) still recognizes the
  RDD operator chain. Scala 2.12+ changed lambda encoding from anonymous inner
  classes to `invokedynamic`/`LambdaMetafactory`; **this will break the current
  decompile-based extraction** and is the main work item here. Options: compile
  benchmarks with `-Ydelambdafy:inline` (keeps anonymous classes) or update the
  extractor to handle indy lambdas.

## Stage 3 — JPF/SPF to JDK 11, then 17 (high risk, the big one)

This is the bulk of the effort.

1. Rebase onto **upstream `jpf-core`** which gained JDK 11+ support, then
   re-apply the BigTest deltas (the diff between the two `jpf-core` trees here is
   small and enumerable: `String`, `System`, `AALOAD`, `DDIV`, `ArrayFields`,
   `DefaultFieldsFactory`, `JPF`, `RunJPF`, `SharedSecrets`).
2. Port `jpf-symbc` + the BigTest `SymExec` listener hooks onto the new core API.
3. Replace `sun.misc.SharedSecrets` usage with supported equivalents.
4. Bump modeled JDK classes to the target JDK's `String`/`System` internals.

Budget this as weeks, not hours; it is a research-grade port. Gate it behind the
Stage-1/2 regression suite.

## Stage 4 — Replace `jad` with CFR (DONE) ✅

`jad` (last released 2001) is the reason benchmarks must target old bytecode and
classic lambdas, and it silently emits raw `JVM INSTR` on patterns it can't
handle (it broke the `commutetrips` demo until that filter was rewritten).

`BIGTEST_DECOMPILER=cfr` now decompiles with **CFR** (`dependencies/cfr.jar`), a
maintained **pure-JVM** decompiler — no native binary, immune to the emulation
ISA problem above, and no bytecode-version ceiling. **Validated: CFR produces
the same `#Valid paths` as jad on all 18 benchmarks** (the 13 TPC-DS/newbench
programs, the 2 paper demos, and the 3 new benchmarks). The default is still
`jad`; flip the default by changing `Configuration.DECOMPILER`.

Implementation: `UDFDecompilerAndExtractor.decompileWithCFR` captures CFR's
(multi-line) source to the `.jad` path; `normalizeCFR` then bridges CFR's AST to
the jad shape the extractor expects, and `UDFWriter` handles CFR's parens
robustly. The four real differences and their fixes:

1. **Generics in type names** (`Tuple2<String,Object>`): stripped in `normalizeCFR`
   using the fact that decompilers write type args with no space before `<`
   (`Tuple2<…>`) while comparisons are spaced (`a < b`), so a comparison like
   `year < 1960` is left intact.
2. **`new StringOps(...).toInt()` parens**: jad wraps it in explicit parens that
   JDT preserves; CFR doesn't. `UDFWriter.rewriteStringOpsToInt` does a
   balanced-paren rewrite to `Integer.parseInt(...)`, careful not to grab an
   enclosing expression's paren (e.g. `(int)(a.toInt() / b.toInt())`).
3. **Erasure / interface casts** (`(Object)`, `(Function1)`, `(Function2)`):
   stripped in `normalizeCFR` (keeping `(String)`/`(int)` which the extractor
   uses to type tuple elements).
4. **`this.`-qualified nested local calls** (`this.getDiff$1(..)`): illegal in the
   static UDF methods we extract; stripped in `normalizeCFR`.

This unblocks Stage 2: a maintained decompiler with no bytecode ceiling is the
prerequisite for moving benchmarks to Spark 3 / newer Scala lambda shapes.

## Suggested order

`Stage 1` (solver) → `Stage 4` (decompiler) → `Stage 2` (Spark/Scala) →
`Stage 3` (JPF/SPF JDK bump). Stages 1 and 4 are independently shippable wins
that de-risk everything after them.
