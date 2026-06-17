# BigTest reproducible build/run environment.
#
# The BigTest artifact ships its own JDK 8, Scala 2.11.12, Spark 2.4.0, cvc5 and
# jad under ../dependencies. Those native binaries are Linux x86-64/i386 ELF, so
# the whole tool only runs on linux/amd64 (emulated via Rosetta/qemu on Apple
# Silicon). This image provides just the missing host build tooling (ant, python,
# 32-bit loader for jad); the repo itself is bind-mounted at /work at run time so
# the bundled dependencies are used verbatim.
FROM --platform=linux/amd64 ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends \
        ant \
        git \
        make \
        python3 \
        ca-certificates \
        libc6-i386 \
        procps \
        bash \
 && rm -rf /var/lib/apt/lists/*

# Keep ant from dragging in a second JDK onto PATH; env.sh points JAVA_HOME at
# the bundled OpenJDK 8 and prepends it to PATH, so the bundled toolchain wins.
WORKDIR /work
ENV BIGTEST_IN_DOCKER=1
CMD ["/bin/bash"]
