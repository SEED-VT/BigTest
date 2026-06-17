#!/usr/bin/env bash
# Compile the original FSE-2019 benchmark suite (with seeded faults) to bytecode.
# Target jvm-1.5 so the bundled jad decompiler can read the class files.
set -e
shopt -s globstar nullglob
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "Compiling BenchmarksFault scala programs (target jvm 1.5, jad-compatible)"
rm -rf bin
mkdir -p bin
scalac -target:jvm-1.5 -d bin -cp "$CLASSPATH" src/**/*.scala
echo "Done. Objects under bin/:"
ls bin
