#!/usr/bin/env bash
# Build and drive BigTest inside the reproducible linux/amd64 container.
#
# Usage:
#   docker/bigtest-docker.sh build              # build the BigTest stack (all JPF + SymExec + UDFExtractor)
#   docker/bigtest-docker.sh bench              # compile the benchmark programs (newbench)
#   docker/bigtest-docker.sh run <mnemonic>     # run BigTest on a benchmark, e.g. movie1, Q1, gradebook
#   docker/bigtest-docker.sh all                # build + bench in one shot
#   docker/bigtest-docker.sh data <mnemonic>    # convert generated SMT models -> job-ready data files
#   docker/bigtest-docker.sh runinput <mnemonic> <pathDir> <n>   # run a generated path through the real Spark job
#   docker/bigtest-docker.sh shell              # interactive shell inside the container
#   docker/bigtest-docker.sh exec <cmd...>      # run an arbitrary command inside the container
#
# The repo is bind-mounted at /work; the bundled JDK8/Scala/Spark/cvc5/jad are
# used verbatim. Build artifacts are written back to the working tree (and are
# .gitignored). Runs as the host user so files stay owned by you.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="bigtest:latest"
PLATFORM="linux/amd64"

ensure_image() {
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo ">> building docker image $IMAGE ..."
    docker build --platform="$PLATFORM" -t "$IMAGE" "$REPO_ROOT/docker"
  fi
}

in_docker() {
  ensure_image
  # Only allocate a TTY when stdin is one (so the script also works in CI/pipes).
  local tty=""; [ -t 0 ] && tty="-it"
  docker run --rm $tty \
    --platform="$PLATFORM" \
    -u "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -v "$REPO_ROOT":/work \
    -w /work \
    "$IMAGE" bash -lc "$1"
}

# Like in_docker but runs as root from /tmp. Needed for anything that boots a
# real SparkContext: Hadoop's UnixLoginModule getpwuid()s the running uid and a
# numeric host uid has no /etc/passwd entry (login NPE). Reads/writes use
# absolute /work paths so nothing root-owned lands in the tree.
in_docker_root() {
  ensure_image
  local tty=""; [ -t 0 ] && tty="-it"
  docker run --rm $tty \
    --platform="$PLATFORM" \
    -e HOME=/root \
    -v "$REPO_ROOT":/work \
    -w /tmp \
    "$IMAGE" bash -lc "$1"
}

cmd="${1:-shell}"; shift || true
case "$cmd" in
  build)
    in_docker 'source BigTest/env.sh && cd BigTest && bash compile.sh'
    ;;
  bench)
    in_docker 'source BigTest/env.sh && cd newbench && bash compile.sh'
    ;;
  all)
    in_docker 'source BigTest/env.sh && (cd BigTest && bash compile.sh) && (cd newbench && bash compile.sh)'
    ;;
  run)
    target="${1:?usage: run <benchmark-mnemonic>}"
    in_docker "source BigTest/env.sh && cd BigTest && bash bigtest.sh '$target'"
    ;;
  data)
    # Convert a run's generated SMT models into job-ready data files under
    # newbench/geninputs/<mnemonic>/path*/<category>/input<N>.
    # Use `data all` to convert every benchmark already under BigTest/runs/.
    target="${1:?usage: data <benchmark-mnemonic>|all}"; shift || true
    if [ "$target" = "all" ]; then
      in_docker 'for d in BigTest/runs/*/; do m=$(basename "$d"); python3 tools/smt_to_data.py "$m" 2>/dev/null && echo "converted $m" || echo "skip $m (no sat paths)"; done'
    else
      in_docker "python3 tools/smt_to_data.py '$target' $*"
    fi
    ;;
  runinput)
    # Feed a generated path's data files to the real Spark job and print output.
    #   runinput <mnemonic> <pathDir> <numInputs>
    mn="${1:?usage: runinput <mnemonic> <pathDir> <numInputs>}"
    dir="${2:?usage: runinput <mnemonic> <pathDir> <numInputs>}"
    n="${3:?usage: runinput <mnemonic> <pathDir> <numInputs>}"
    in_docker_root "source /work/BigTest/env.sh >/dev/null 2>&1 && \
      java -cp /work/newbench/bin:\$CLASSPATH -Dderby.system.home=/tmp \
        utils.RunGenerated '$mn' '/work/$dir' '$n' 2>/dev/null"
    ;;
  shell)
    in_docker 'source BigTest/env.sh; exec bash'
    ;;
  exec)
    in_docker "source BigTest/env.sh && $*"
    ;;
  *)
    echo "unknown command: $cmd" >&2
    sed -n '2,20p' "${BASH_SOURCE[0]}"
    exit 1
    ;;
esac
