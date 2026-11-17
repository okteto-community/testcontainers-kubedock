#!/bin/sh
# Prints a kubeconfig for your current Okteto context and namespace, with a Kubernetes token that
# is valid for 24 hours. Unlike the one `okteto kubeconfig` writes, it doesn't need the Okteto CLI,
# so kubedock can use it inside a build.
set -eu

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
KUBECONFIG="$tmp" okteto kubeconfig > /dev/null

server=$(KUBECONFIG="$tmp" kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
token=$(okteto kubetoken | tr -d '\n' | sed -E 's/.*"token": *"([^"]+)".*/\1/')

cat <<KUBECONFIG
apiVersion: v1
kind: Config
clusters:
  - name: okteto
    cluster:
      server: $server
users:
  - name: okteto
    user:
      token: $token
contexts:
  - name: okteto
    context:
      cluster: okteto
      user: okteto
current-context: okteto
KUBECONFIG
