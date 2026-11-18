# Testcontainers with kubedock on Okteto

Runs a [Testcontainers](https://testcontainers.com) test suite on Okteto without a Docker daemon
and without any change to Okteto. [kubedock](https://github.com/joyrex2001/kubedock) implements the
Docker API and runs every container the tests ask for as a pod in your namespace.

The sample is a small Scala web app built with Maven. Its tests start a Postgres container.

```bash
okteto deploy      # builds the app without the tests and deploys it
okteto test unit   # runs the tests, with Postgres as a pod in your namespace
```

## How it works

| Command | What it does |
|---|---|
| `okteto build` | Builds the image without the tests. |
| `okteto deploy` | Builds the image and deploys the app (`k8s.yml`), with a public endpoint. |
| `okteto test unit` | Starts kubedock, runs `mvn test` against it and downloads the test reports to `target/test-reports`. |

In `okteto test`, one command does the work:

```yaml
- ./with-kubedock.sh mvn -B test
```

`with-kubedock.sh` starts kubedock in the background, waits until it answers, and runs the tests
with `DOCKER_HOST` pointing to it, so Testcontainers talks to kubedock instead of a Docker daemon.
kubedock creates a pod for each container with the Kubernetes credentials Okteto already gives the
test container, and deletes it when the test stops the container. When the tests end, the script
stops kubedock.

kubedock only listens on `127.0.0.1` and only lives while `okteto test` runs, so nobody else can use
it to create pods, and the pods are created with your own permissions. This relies on BuildKit
giving each run a network of its own: the sample doesn't support BuildKit in rootless mode or with
`network.mode` set to `host`, and the script fails if something already answers on its port.

## Faster runs

- `okteto test` caches the Maven repository (`/root/.m2`) and the kubedock binary
  (`/root/.kubedock`), so later runs don't download them again.
- The `Dockerfile` downloads the dependencies in their own layer and uses a BuildKit cache for
  `/root/.m2`, so a change in `src/` doesn't download them again.
- `.dockerignore` only sends `pom.xml` and `src/` to the build, and `.oktetoignore` doesn't upload
  `target/` to `okteto test`.

## Things to know

- **Ryuk is disabled** (`TESTCONTAINERS_RYUK_DISABLED=true`). Ryuk mounts the Docker socket, and
  the script turns off the Docker socket support of kubedock (`--disable-dind`). The tests stop
  their containers, and kubedock deletes the pods.
- **Test runs in the same namespace go one at a time** (`--lock`). Two runs using the same network
  alias would otherwise collide, because kubedock creates a Service named after each alias.
- **A cancelled run leaves its pods behind** until the next run starts, which deletes them
  (`--prune-start`). Delete them sooner with `kubectl delete pods,services -l kubedock=true`.
