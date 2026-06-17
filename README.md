# Configure & compile
This project has a nested dependency and has strict dependency on the java/scala version.

To configure, run `env.sh` in `<rootpath>/BigTest`.

To compile, run `compile.sh` in `<rootpath>/BigTest`. This command will compile the 1-st/2nd layer JPF + SymExec + UDFExtractor. Ant is needed.

# Run a benchmark
Q1 is a benchmark from TPC-DS, put in `newbench/src/Q1/Q1.scala`. Here, `Q1` is a mnemonic for benchmark, while its real bytecode file is defined in `<rootpath>/BigTest/init.sh`.

To compile Q1, run `./compile` under `<rootdir>/newbench`

To run BigTest, run `./bigtest.sh movie1`.

After running, you'll see in `<rootpath>/BigTest/Rundir`

1. *.jad, that is the decompiled file.
2. *.java, extracted out UDFs.
3. *.smt2, satisfiable path constraints.

Hardcoded paths should've been fixed for running BigTest.

To add more benchmarks, you need to 

1. Include them in `init.sh`.
2. Remember to compile the new bench first.

# Misc
1. `udf.sh` is used to debug single udfs. But may have hardcoded paths now.
2. Other scripts in SymExec or UDFExtractor may also be outdated.
3. Currently, we use CVC5. Z3 may have some problem with existing SMT2 generator.
4. We limit isinteger to only handle non-negative integers in SMT formula generation, as CVC5/Z3 both have problems dealing with `str.to.int` or `int.to.str` negative numbers
5. To add new bench, you may need to inspect the [1] udf extraction procedure, [2] smt generation procedure, as current tool can be shaky.
6. The new version of BigTest has only been tested on newbench, while not tested on the old benches (although seems to work, but for example not verified whether it could detect the seeded faults in the original paper)