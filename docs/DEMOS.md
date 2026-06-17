# Paper demos

Faithful, runnable reproductions of the two worked examples from the BigTest
papers. Both are wired into the `newbench` harness and registered in
`BigTest/init.sh`.

Run them with:

```bash
./docker/bigtest-docker.sh build      # once
./docker/bigtest-docker.sh bench      # once (compiles the demos too)
./docker/bigtest-docker.sh run gradebook
./docker/bigtest-docker.sh run commutetrips
```

---

## ICSE 2020 demo — `gradebook`

Source: [newbench/src/gradebook/gradebook.scala](../newbench/src/gradebook/gradebook.scala)
(Figure 2 of the ICSE 2020 demo paper.)

> "A Spark program that identifies the courses with less than two failing students."

```scala
input1
  .map { line => val arr = line.split(","); arr(1) }
  .map { l => val a = l.split(":"); (a(0), Integer.parseInt(a(1))) }
  .map { a => if (a._2 > 40) ("Pass".concat(a._1), 1) else ("Fail".concat(a._1), 1) }
  .reduceByKey(_ + _)
  .filter(v => v._2 <= 2 && v._1.startsWith("Fail"))
```

A gradebook row is `courseId:mark,year,studentId,session,major`. The program has
17 JDU paths (2 non-terminating, 15 terminating). Testing only on top-100
passing records exercises 12, missing crash paths around `Integer.parseInt` and
the off-by-one bug (`<=` should be `<`).

What BigTest produces (illustrative): satisfiable paths whose SMT models give
inputs such as `",:90"` (→ `arr(1)=":90"` → mark 90 → **Pass**, filtered out by
`startsWith("Fail")`) and `Fail`-key paths with count ≤ 2. The
`isInteger`/`notinteger` terminating paths drive empty / non-numeric inputs that
expose the `parseInt` crash.

This demo exercises BigTest's **`String.startsWith` modeling** — see
[docs/MAINTENANCE.md](MAINTENANCE.md): the `startswith`/`notstartswith`
constraint operators were missing and are now compiled to SMT `str.prefixof`.

---

## FSE 2019 demo — `commutetrips`

Source: [newbench/src/commutetrips/commutetrips.scala](../newbench/src/commutetrips/commutetrips.scala)
(Figure 2 of the FSE 2019 paper — Alice's program that "estimates the total
number of trips originated from 'Palms'".)

```scala
val trips = input1.map { s => val c = s.split(","); (c(1), c(3).toInt / c(4).toInt) }   // (location, speed)
val zip   = input2.map { s => val c = s.split(","); (c(1), c(0)) }                       // (location, name)
                  .filter(s => s._2.equals("Palms"))
trips.join(zip)
     .map { s => if (s._2._1 > 40) ("car",1) else if (s._2._1 > 15) ("bus",1) else ("walk",1) }
     .reduceByKey(_ + _)
```

Two input tables joined on a location key. This program exercises BigTest's
join modeling (the matched/non-terminating case **and** the two terminating
cases where a key is present in only one table), integer **division**
(`c(3).toInt / c(4).toInt`, incl. divide-by-zero), and string segmentation
(`split` length, `isInteger`).

Representative generated inputs:

| path kind                  | trips (`input1`)   | zip (`input2`) |
|----------------------------|--------------------|----------------|
| matched join, speed→`car`  | `",,,90,1"`        | `"Palms,"`     |
| non-integer distance crash | `",A,,0,9"`        | `"Palms,"`     |
| key only in right table    | —                  | `","`          |

This demo exercises BigTest's **integer-division SMT encoding** — see
[docs/MAINTENANCE.md](MAINTENANCE.md): division now emits SMT `div` (integer)
instead of `/` (real), which cvc5 rejected in the integer logic.

> Note on `==` vs `.equals`: the paper writes `s._2 == "Palms"`. Scala's `==` on
> a tuple-extracted value compiles to a null-checked `BoxesRunTime.equals` whose
> bytecode `jad` cannot decompile. The demo uses the semantically identical
> `.equals("Palms")`, matching the other join benchmarks (`airport`, `usedcars`).
