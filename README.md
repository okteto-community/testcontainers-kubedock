# Testcontainers with kubedock on Okteto

Runs a [Testcontainers](https://testcontainers.com) test suite on Okteto without a Docker daemon.
[kubedock](https://github.com/joyrex2001/kubedock) implements the Docker API and runs every
container the tests ask for as a pod in your namespace.

## How it works

`start-kubedock.sh` starts kubedock in the background, listening only on `127.0.0.1`. The next
commands point Testcontainers to it:

```bash
./start-kubedock.sh
DOCKER_HOST=tcp://127.0.0.1:2475 TESTCONTAINERS_RYUK_DISABLED=true mvn -B test
```

kubedock creates a pod for each container (here, Postgres) with your own Kubernetes credentials,
and deletes it when the test stops the container. Nothing is deployed in your namespace and nothing
listens outside the command that runs the tests, so nobody else can use kubedock to create pods.

## Run the tests in `okteto test` and `okteto deploy`

Okteto already gives test and deploy commands your Kubernetes credentials, so there's nothing else
to set up. `Dockerfile` builds the app without the tests.

```bash
okteto test unit
okteto deploy
```

## Run the tests in `okteto build`

`Dockerfile.tests-in-build` runs the tests in the `RUN` step that builds the app. The build doesn't
get your Kubernetes credentials, so `kubeconfig.sh` creates a kubeconfig with your token, valid for
24 hours, and the build gets it as a secret. It isn't stored in the image or its history.

```bash
export KUBEDOCK_KUBECONFIG="$(./kubeconfig.sh)"
okteto build -f okteto-tests-in-build.yml
```

## Things to know

- **Ryuk is disabled** (`TESTCONTAINERS_RYUK_DISABLED=true`). Ryuk needs the Docker socket, which
  kubedock doesn't have. The tests stop their containers, and kubedock deletes the pods.
- **Runs in the same namespace go one at a time** (`--lock`). Two runs using the same network alias
  would otherwise collide, because kubedock creates a Service named after each alias.
- **A cancelled run leaves its pods behind** until the next run starts, which deletes them
  (`--prune-start`). Delete them sooner with `kubectl delete pods,services -l kubedock=true`.
