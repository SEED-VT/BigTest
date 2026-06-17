export BigTest=$(realpath $(dirname ${BASH_SOURCE}))
dependencies=$(realpath $(dirname ${BASH_SOURCE})/../dependencies)
echo HomeDir of bigtest: $BigTest
echo Dependency: $dependencies
export JAVA_HOME=$dependencies/openlogic-openjdk-8u352-b08-linux-x64
export SCALA_HOME=$dependencies/scala-2.11.12
export SPARK_HOME=$dependencies/spark-2.4.0-bin-hadoop2.7 #2.1.0
export JUINT_HOME=$dependencies/junit

export PATH=$JAVA_HOME/bin:$PATH # java path
export PATH=$SCALA_HOME/bin:$PATH # scala path
export PATH=$SPARK_HOME/bin:$PATH # spark path
export PATH=$PATH:$dependencies # join my own path

export CLASSPATH=$CLASSPATH:$JUINT_HOME/ # junit
export CLASSPATH=$CLASSPATH:$dependencies/jdt2/* #decompilers
export CLASSPATH=$CLASSPATH:$SPARK_HOME/jars/*

# Modernization hooks (see docs/MODERNIZATION.md):
#   BIGTEST_SOLVER     full solver invocation; SMT2 fed on stdin. Default: cvc5
#                      e.g. export BIGTEST_SOLVER="cvc5 --strings-exp --lang smt2"
#                           export BIGTEST_SOLVER="z3 -in -smt2"
#   BIGTEST_DECOMPILER jad (default) | cfr (experimental, pure-JVM decompiler)