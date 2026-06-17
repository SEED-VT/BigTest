# BigTest

BigTest is a white-box test-input generation tool for data-intensive scalable
computing (DISC) applications written for Apache Spark. Given a Spark program, it
automatically synthesizes a small set of concrete input records that
systematically exercise the program's combined dataflow and user-defined-function
(UDF) behaviour, so that corner cases can be tested locally in seconds rather than
by running the application over terabytes of production data.

The technique was introduced in the following publications, and this repository
is a maintained, runnable version of the accompanying artifact:

- **White-Box Testing of Big Data Analytics with Complex User-Defined Functions.**
  Muhammad Ali Gulzar, Shaghayegh Mardani, Madanlal Musuvathi, and Miryung Kim.
  *ESEC/FSE 2019.* DOI: [10.1145/3338906.3338953](https://doi.org/10.1145/3338906.3338953)
- **BigTest: A Symbolic Execution Based Systematic Test Generation Tool for Apache Spark.**
  Muhammad Ali Gulzar, Madanlal Musuvathi, and Miryung Kim. *ICSE 2020 (Companion).*
  DOI: [10.1145/3377812.3382145](https://doi.org/10.1145/3377812.3382145).
  Demonstration video: <https://youtu.be/OeHhoKiDYso>

---

## Table of contents

- [Motivation](#motivation)
- [How BigTest works](#how-bigtest-works)
- [Repository layout](#repository-layout)
- [Requirements and platform notes](#requirements-and-platform-notes)
- [Installation](#installation)
- [Usage](#usage)
- [Output](#output)
- [From SMT models to job-ready data files](#from-smt-models-to-job-ready-data-files)
- [Benchmarks](#benchmarks)
- [Worked examples from the papers](#worked-examples-from-the-papers)
- [Configuration](#configuration)
- [Authoring new benchmarks](#authoring-new-benchmarks)
- [Modernization status](#modernization-status)
- [Troubleshooting](#troubleshooting)
- [Further documentation](#further-documentation)
- [Citing BigTest](#citing-bigtest)
- [License and acknowledgements](#license-and-acknowledgements)

---

## Motivation

DISC systems such as Google MapReduce, Apache Hadoop, and Apache Spark routinely
process terabytes of data. At that scale, rare and buggy corner cases appear
frequently in production, and an application may run for hours before crashing or,
worse, silently producing corrupted output. The common practice of testing such
applications on a small random sample of the input rarely covers these corner
cases.

Unlike SQL queries, DISC applications combine *relational operators* (such as join
and group-by) and *dataflow operators* (such as map and flatMap) with arbitrarily
complex *user-defined functions* written in a general-purpose language. Testing
them well therefore requires reasoning about the internal logic of the UDFs
together with the semantics of the operators that surround them.

BigTest addresses this by reasoning about the combined behaviour of UDFs and
dataflow/relational operators. The original evaluation reports that real-world
datasets are highly skewed and leave roughly a third of *Joint Dataflow and UDF*
(JDU) paths untested; that BigTest reveals about twice as many manually injected
faults as the prior approach; and that it reduces the data required for local
testing by five to eight orders of magnitude, yielding average CPU-time savings of
around 194×, while synthesizing inputs for the remaining untested paths in
seconds.

## How BigTest works

BigTest does not execute Apache Spark. Instead, it abstracts the framework's
dataflow operators with clean logical specifications and applies symbolic
execution only to the UDFs. The pipeline has four stages:

1. **Program decomposition.** The compiled program is decompiled and its abstract
   syntax tree is analysed to extract each UDF into a standalone class, together
   with the configuration needed to symbolically execute it.
2. **Path-constraint generation.** Each UDF is symbolically executed with Symbolic
   PathFinder. The resulting path conditions and effects are combined with the
   logical specification of the enclosing operator. BigTest models both the
   non-terminating and the *terminating* cases of each operator — for example, a
   join key that is present only in the left table, only in the right table, or in
   neither — because these often produce the null entries that cause failures. It
   also models collections produced by `flatMap` and turns aggregation logic such
   as `reduceByKey` into an iterative aggregator with a bounded loop, and it
   reasons explicitly about string operations such as `split` and `isInteger`.
3. **Test-data generation.** Each end-to-end path constraint is translated into an
   SMT-LIB query (with a small library of functions for unsupported operations
   such as string split and `isInteger`) and solved by an off-the-shelf theorem
   prover to obtain satisfying input records.
4. **Result.** For every satisfiable JDU path, BigTest emits the SMT query and a
   concrete set of input rows that exercise that path.

## Repository layout

```
BigTest/                 The tool
  jpf-core/              Java PathFinder (model checker)              [runtime]
  jpf-symbc/             Symbolic PathFinder, extended for BigTest    [runtime]
  SymExec/               Symbolic dataset operators and SMT generation (Scala)
  UDFExtractor/          bytecode -> decompiler -> Eclipse JDT AST -> UDFs (Java)
  BenchmarksFault/       Original FSE-2019 benchmarks with seeded faults
  env.sh init.sh compile.sh bigtest.sh
jpf-core/  jpf-symbc/     A second JPF pair, used only to compile SymExec/UDFExtractor
newbench/                Benchmark suite (TPC-DS Q1..Q20, plus demos and others)
tools/                   smt_to_data.py — turn generated models into job-ready data
docker/                  Reproducible linux/amd64 build-and-run environment
docs/                    DEMOS, MAINTENANCE, and MODERNIZATION notes
dependencies/            Bundled JDK 8, Scala 2.11.12, Spark 2.4.0, cvc5, jad, CFR
```

## Requirements and platform notes

BigTest is built on a customized fork of Java PathFinder and Symbolic PathFinder
and targets **Java 8 / Scala 2.11 / Spark 2.4**. The original toolchain is bundled
under `dependencies/` so that no global installation is required.

The bundled `cvc5` (SMT solver) and `jad` (decompiler), along with the bundled
JDK, are **Linux x86 binaries**. They do not run natively on macOS (Apple Silicon
or Intel). For this reason the supported way to build and run BigTest is the
Docker environment described below, which executes the bundled binaries under
`linux/amd64`. On an Apple-Silicon host this uses Rosetta/qemu emulation, which has
been validated for cvc5 1.0.5, jad 1.5.8e, and OpenJDK 8u352. The JVM components of
the tool compile on any JDK 8 host, but running end to end requires the native
binaries and therefore the container (or a real Linux x86-64 machine).

**Prerequisites**

- [Docker](https://www.docker.com/) (Docker Desktop on macOS/Windows, or Docker
  Engine on Linux). No other software is required on the host.

## Installation

Clone the repository and build the container image and the tool. The helper script
`docker/bigtest-docker.sh` builds the image on first use and runs all subsequent
commands inside it, bind-mounting the repository so the bundled dependencies are
used verbatim.

```bash
git clone https://github.com/maligulzar/BigTest.git
cd BigTest

# Build the BigTest stack (both JPF trees, SymExec, and UDFExtractor) and
# compile the benchmark programs to bytecode. This also builds the image.
./docker/bigtest-docker.sh all
```

`all` is equivalent to running `build` (compile the tool) followed by `bench`
(compile the benchmarks). The image can also be built explicitly with
`docker build --platform=linux/amd64 -t bigtest:latest docker/`.

### Building on a native Linux x86-64 host (optional)

On a Linux x86-64 machine the bundled binaries run directly, so Docker is not
required. Apache Ant is needed in addition to the bundled toolchain:

```bash
source BigTest/env.sh            # sets JAVA_HOME, SCALA_HOME, SPARK_HOME from dependencies/
( cd BigTest  && bash compile.sh )
( cd newbench && bash compile.sh )
( cd BigTest  && bash bigtest.sh movie1 )
```

## Usage

All commands are issued through the helper script.

```bash
./docker/bigtest-docker.sh build              # compile the tool
./docker/bigtest-docker.sh bench              # compile the benchmark programs
./docker/bigtest-docker.sh all                # build + bench

./docker/bigtest-docker.sh run <mnemonic>     # run BigTest on a benchmark
./docker/bigtest-docker.sh data <mnemonic>    # convert a run's models to data files
./docker/bigtest-docker.sh data all           # convert every benchmark already run
./docker/bigtest-docker.sh runinput <mnemonic> <pathDir> <numInputs>
                                              # run a generated path through real Spark

./docker/bigtest-docker.sh shell              # interactive shell in the environment
./docker/bigtest-docker.sh exec <command...>  # run an arbitrary command in the environment
```

For example, to generate tests for the `movie1` benchmark:

```bash
./docker/bigtest-docker.sh run movie1
```

The benchmark mnemonics are defined in [`BigTest/init.sh`](BigTest/init.sh); see
[Benchmarks](#benchmarks).

## Output

Each run writes its working artifacts to `BigTest/Rundir/` (which is cleared at the
start of every run) and prints the generated test inputs to the console. Because
`Rundir/` is overwritten on each run, the results are also archived, per benchmark,
to `BigTest/runs/<mnemonic>/`:

| File                | Contents                                                 |
|---------------------|----------------------------------------------------------|
| `console.log`       | The full run log.                                        |
| `inputs.txt`        | The generated test inputs and per-path solver verdicts.  |
| `<prog>$.jad`       | The decompiled program.                                  |
| `<udf>.java`        | Each extracted UDF, one per dataflow operator.           |
| `<udf>.jpf`         | The generated Symbolic PathFinder configuration.         |
| `<n>.smt2`          | The SMT-LIB query for each satisfiable JDU path.         |

The console summary reports the number of satisfiable paths (`#Valid paths`) and
the total test-generation, solver, and constraint-generation times. For each
satisfiable path, the concrete input rows are printed as SMT model assignments,
for example `(define-fun input1 () String ",1910,,9")`.

## From SMT models to job-ready data files

The solver models *are* the input rows. `run` automatically materializes them as
line-delimited data files that the Spark jobs can read, and the same conversion
can be performed or repeated explicitly:

```bash
./docker/bigtest-docker.sh run movie1     # generates and converts in one step
./docker/bigtest-docker.sh data movie1    # (re)convert a single benchmark
./docker/bigtest-docker.sh data all       # convert every benchmark under BigTest/runs/
```

The files are written to `newbench/geninputs/<mnemonic>/path<k>/primitive/input<N>`,
one file per input table per path, in the layout consumed by the `utils.TestSuite`
harness (the first line is treated as a header and skipped). A path that requires
several records emits them as separate rows; join programs produce one file per
table. To run a generated path through the actual Spark job and observe its output:

```bash
./docker/bigtest-docker.sh runinput movie1 newbench/geninputs/movie1/path1/primitive 1
```

`newbench/geninputs/` contains generated output and is ignored by Git.

## Benchmarks

Benchmark mnemonics are defined in [`BigTest/init.sh`](BigTest/init.sh).

**newbench** (compiled by `bench`):

| Mnemonic        | Description                                            |
|-----------------|--------------------------------------------------------|
| `movie1`        | Filter and aggregate highly rated vintage films.       |
| `transit`       | Compute airport dwell times with substring parsing.    |
| `credit`        | Join personal and bank records.                        |
| `airport`       | Join airport location and status tables.               |
| `usedcars`      | Join used-car listings and sales.                      |
| `Q1`,`Q3`,`Q6`,`Q7`,`Q12`,`Q15`,`Q19`,`Q20` | TPC-DS-derived queries.    |
| `gradebook`     | ICSE 2020 demo: courses with fewer than two failures.  |
| `commutetrips`  | FSE 2019 demo: trips originating from "Palms".          |
| `weblog`        | `flatMap` of log events; count errors per service.     |
| `sales`         | Join orders and products; revenue tiers per category.  |
| `temps`         | Parse and filter weather readings.                     |

**BenchmarksFault** (the original FSE-2019 set with seeded faults; compile with
`./docker/bigtest-docker.sh exec 'cd BigTest/BenchmarksFault && bash compile.sh'`):
`wordcount`, `movieratings`, `income`, `StudentGrades`, `commute`, `l2`.

All of the above are verified to build and generate test inputs in the Docker
environment.

## Worked examples from the papers

Two benchmarks are faithful reproductions of the worked examples in the papers and
are documented step by step in [`docs/DEMOS.md`](docs/DEMOS.md):

- `gradebook` — the ICSE 2020 program that identifies courses with fewer than two
  failing students. BigTest generates inputs that reach the `Integer.parseInt`
  crash paths and the off-by-one predicate fault.
- `commutetrips` — the FSE 2019 program that estimates the number of trips
  originating from "Palms". It exercises BigTest's join modelling (including the
  terminating cases where a key is absent from one table), integer division, and
  string segmentation.

## Configuration

- **Loop and collection bound.** The exploration bound `K_BOUND` (default 2) limits
  the unrolling of unbounded loops and collections; it is defined in
  [`BigTest/UDFExtractor/src/udfExtractor/Configuration.java`](BigTest/UDFExtractor/src/udfExtractor/Configuration.java).
- **Solver.** The SMT solver is configurable through the `BIGTEST_SOLVER`
  environment variable; the query is supplied on standard input. The default is the
  bundled `cvc5`. Examples: `BIGTEST_SOLVER="cvc5 --strings-exp --lang smt2"` or
  `BIGTEST_SOLVER="z3 -in -smt2"`.
- **Decompiler.** `BIGTEST_DECOMPILER` selects the decompiler: `jad` (default) or
  `cfr`, a maintained pure-JVM decompiler. CFR has been validated to produce
  identical results to jad on all benchmarks.
- **Data generators.** The `.config` files under `newbench/config/` describe input
  distributions for the evaluation harness; they are not required for symbolic
  test generation.

These hooks are also documented in [`BigTest/env.sh`](BigTest/env.sh) and
[`docs/MODERNIZATION.md`](docs/MODERNIZATION.md).

## Authoring new benchmarks

To add a benchmark, place a program under `newbench/src/<name>/<name>.scala` that
extends `utils.SparkProgramTemplate` (overriding the `execute` arity you need),
register it in [`BigTest/init.sh`](BigTest/init.sh), then run `bench` followed by
`run <name>`. Two properties of the extractor are worth observing:

- **Use a tuple field in a typed operation before re-tupling it.** BigTest infers a
  tuple field's type from how it is used. Passing a field straight into a new tuple,
  as in `map(t => (t._1, 1))`, leaves the type undetermined and the run fails with
  `Couldn't guess the type of t._1`. Use the field in a comparison or string
  operation first, or filter on the raw string and derive the key from a fresh
  `split(...)` (see `temps` and `weblog`).
- **Prefer `.equals(...)` to `==` for string comparisons.** Scala's `==` emits a
  null-checked `BoxesRunTime.equals` that the jad decompiler cannot decompile.

## Modernization status

This repository has been brought back to a building and running state, and parts of
the toolchain have been modernized. The default path (jad plus the bundled cvc5) is
unchanged; the following are additive and selected by environment variables:

- A configurable solver (`BIGTEST_SOLVER`), so any current cvc5 or Z3 build can be
  used on a Linux host.
- An optional, maintained, pure-JVM decompiler (`BIGTEST_DECOMPILER=cfr`),
  validated to match the bundled jad on every benchmark and free of jad's
  bytecode-version ceiling.

Porting the benchmarks to Spark 3 and the JPF/SPF core to a newer JDK are larger,
still-open efforts. The staged plan and rationale are recorded in
[`docs/MODERNIZATION.md`](docs/MODERNIZATION.md), and the repair history is in
[`docs/MAINTENANCE.md`](docs/MAINTENANCE.md).

## Troubleshooting

- **`Cannot connect to the Docker daemon`.** Start Docker Desktop (macOS/Windows)
  or the Docker service (Linux) and retry.
- **`Illegal instruction` from a non-bundled solver.** Newer cvc5 release binaries
  target a CPU instruction set that the Apple-Silicon emulation layer does not
  support. Use the bundled cvc5 1.0.5 on this platform, or a newer solver on a real
  Linux x86-64 host.
- **`Q20` reports one extra path occasionally.** `Q20` is the largest and most
  timing-sensitive benchmark; under heavy batch load the path count can read 20
  rather than 19. Re-running it in isolation gives the stable value.
- **A new benchmark fails with `Couldn't guess the type of …`.** See
  [Authoring new benchmarks](#authoring-new-benchmarks).

## Further documentation

- [`docs/DEMOS.md`](docs/DEMOS.md) — step-by-step walkthroughs of the paper examples.
- [`docs/MAINTENANCE.md`](docs/MAINTENANCE.md) — what was repaired to restore the build.
- [`docs/MODERNIZATION.md`](docs/MODERNIZATION.md) — the staged modernization plan and status.

## Citing BigTest

If you use BigTest in academic work, please cite the FSE 2019 paper; the ICSE 2020
companion describes the tool itself.

```bibtex
@inproceedings{gulzar2019bigtest,
  author    = {Gulzar, Muhammad Ali and Mardani, Shaghayegh and Musuvathi, Madanlal and Kim, Miryung},
  title     = {White-Box Testing of Big Data Analytics with Complex User-Defined Functions},
  booktitle = {Proceedings of the 27th ACM Joint European Software Engineering Conference and Symposium on the Foundations of Software Engineering (ESEC/FSE)},
  year      = {2019},
  pages     = {290--301},
  doi       = {10.1145/3338906.3338953}
}

@inproceedings{gulzar2020bigtest,
  author    = {Gulzar, Muhammad Ali and Musuvathi, Madanlal and Kim, Miryung},
  title     = {BigTest: A Symbolic Execution Based Systematic Test Generation Tool for Apache Spark},
  booktitle = {Proceedings of the 42nd International Conference on Software Engineering (ICSE) Companion},
  year      = {2020},
  doi       = {10.1145/3377812.3382145}
}
```

## License and acknowledgements

BigTest builds on [Java PathFinder](https://github.com/javapathfinder) and
Symbolic PathFinder, which are distributed under the Apache License 2.0 (see the
`LICENSE-2.0.txt` files under `jpf-core/` and `jpf-symbc/`). The bundled
dependencies — OpenJDK, Scala, Apache Spark, cvc5, jad, and CFR — are the property
of their respective authors and remain under their own licenses.

The research was supported in part by a Google PhD Fellowship and by grants from
the National Science Foundation, the Office of Naval Research, Intel, and Samsung,
as acknowledged in the papers.
