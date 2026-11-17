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
| `okteto build` | Builds the image with `SKIP_TESTS=true`. Okteto builds don't have a Docker API for Testcontainers. |
| `okteto deploy` | Builds the image and deploys the app (`k8s.yml`), with a public endpoint. |
| `okteto test unit` | Starts kubedock, runs `mvn test` against it and downloads the test reports to `target/test-reports`. |

In `okteto test`, two commands do the work:

```yaml
- ./start-kubedock.sh
- DOCKER_HOST=tcp://127.0.0.1:2475 TESTCONTAINERS_RYUK_DISABLED=true mvn -B test
```

`start-kubedock.sh` starts kubedock in the background and waits until it answers. It keeps
running for the next command, where Testcontainers talks to it instead of a Docker daemon. kubedock
creates a pod for each container with the Kubernetes credentials Okteto already gives the test
container, and deletes it when the test stops the container.

kubedock only listens on `127.0.0.1` and only lives while `okteto test` runs, so nobody else can use
it to create pods, and the pods are created with your own permissions.

## Running the tests in the build anyway

The `Dockerfile` runs the tests by default. `okteto.yml` turns them off with a build argument:

```yaml
build:
  app:
    args:
      SKIP_TESTS: "true"
```

So a CI that builds the image with a Docker daemon available keeps running the tests in the build,
and Okteto runs them in `okteto test`.

## Faster runs

- `okteto test` caches the Maven repository (`/root/.m2`) and the kubedock binary
  (`/root/.kubedock`), so later runs don't download them again.
- The `Dockerfile` downloads the dependencies in their own layer and uses a BuildKit cache for
  `/root/.m2`, so a change in `src/` doesn't download them again.
- `.dockerignore` only sends `pom.xml` and `src/` to the build, and `.oktetoignore` doesn't upload
  `target/` to `okteto test`.

## Things to know

- **Ryuk is disabled** (`TESTCONTAINERS_RYUK_DISABLED=true`). Ryuk needs the Docker socket, which
  kubedock doesn't have. The tests stop their containers, and kubedock deletes the pods.
- **Test runs in the same namespace go one at a time** (`--lock`). Two runs using the same network
  alias would otherwise collide, because kubedock creates a Service named after each alias.
- **A cancelled run leaves its pods behind** until the next run starts, which deletes them
  (`--prune-start`). Delete them sooner with `kubectl delete pods,services -l kubedock=true`.
