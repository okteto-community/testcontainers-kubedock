#!/bin/sh
# Runs a command with kubedock as its Docker API:
#
#   ./with-kubedock.sh mvn -B test
#
# kubedock runs every container the command starts as a pod in your namespace, with your own
# Kubernetes credentials. It only listens on 127.0.0.1, and it stops when the command ends.
set -eu

version=0.23.0
addr=127.0.0.1:2475
# Cache this directory between runs to skip the download (see okteto.yml).
dir="$HOME/.kubedock/$version"
bin="$dir/kubedock"

# 127.0.0.1 must be private to this run. If another kubedock answers on it, the containers would
# run with its credentials, in its namespace.
if curl -sf "http://$addr/_ping" > /dev/null; then
  echo "Something already answers on $addr. BuildKit must give each run a network of its own." >&2
  exit 1
fi

if [ ! -x "$bin" ]; then
  arch=$(uname -m | sed 's/aarch64/arm64/')
  tarball="kubedock_linux_${arch}.tar.gz"
  url="https://github.com/joyrex2001/kubedock/releases/download/$version"
  mkdir -p "$dir"
  curl -sfL -o "$dir/$tarball" "$url/$tarball"
  # Check the download against the checksums of the release.
  curl -sfL "$url/kubedock_${version}_checksums.txt" | grep " $tarball\$" | (cd "$dir" && sha256sum -c -)
  tar -xzf "$dir/$tarball" -C "$dir" kubedock
  rm "$dir/$tarball"
fi

# --lock: runs in the same namespace wait for each other instead of colliding on network aliases.
# --prune-start: once it holds the lock, kubedock deletes what a cancelled run left behind.
"$bin" server \
  --kubeconfig "${KUBECONFIG:-$HOME/.kube/config}" \
  --namespace "$OKTETO_NAMESPACE" \
  --listen-addr "$addr" \
  --port-forward \
  --disable-dind \
  --lock \
  --prune-start \
  > /tmp/kubedock.log 2>&1 &
pid=$!

# When the command ends, stop kubedock with SIGTERM: it deletes its pods and releases the lock, so
# the next run in the namespace doesn't wait for it.
trap 'kill "$pid" 2> /dev/null && wait "$pid" 2> /dev/null || true' EXIT

# kubedock only starts listening once it holds the lock.
until curl -sf "http://$addr/_ping" > /dev/null; do
  if ! kill -0 "$pid" 2> /dev/null; then
    cat /tmp/kubedock.log
    exit 1
  fi
  sleep 1
done

# Ryuk mounts the Docker socket, which --disable-dind turns off, so Testcontainers runs without it.
DOCKER_HOST="tcp://$addr" TESTCONTAINERS_RYUK_DISABLED=true "$@"
