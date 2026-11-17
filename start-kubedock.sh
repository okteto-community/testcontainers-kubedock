#!/bin/sh
# Starts kubedock in the background and waits until it answers. Point Testcontainers to it with
# DOCKER_HOST=tcp://127.0.0.1:2475 and it runs every container as a pod in your namespace, with
# your own Kubernetes credentials. It only listens on 127.0.0.1, so nobody else can use it.
set -eu

if ! command -v kubedock > /dev/null; then
  arch=$(uname -m | sed 's/aarch64/arm64/')
  curl -sfL "https://github.com/joyrex2001/kubedock/releases/download/0.23.0/kubedock_linux_${arch}.tar.gz" \
    | tar -xz -C /usr/local/bin kubedock
fi

# --lock: runs in the same namespace wait for each other instead of colliding on network aliases.
# --prune-start: once it holds the lock, kubedock deletes what a cancelled run left behind.
kubedock server \
  --kubeconfig "${KUBECONFIG:-$HOME/.kube/config}" \
  --namespace "$OKTETO_NAMESPACE" \
  --listen-addr 127.0.0.1:2475 \
  --port-forward \
  --disable-dind \
  --lock \
  --prune-start \
  > /tmp/kubedock.log 2>&1 &

# kubedock only starts listening once it holds the lock.
until curl -sf http://127.0.0.1:2475/_ping > /dev/null; do
  if ! kill -0 $! 2> /dev/null; then
    cat /tmp/kubedock.log
    exit 1
  fi
  sleep 1
done
