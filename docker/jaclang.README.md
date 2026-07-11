# jaseci/jaclang

The official image for [Jac](https://www.jac-lang.org): the self-contained
`jac` binary on a slim Debian base, with the runtime pre-extracted and the
scale serving stack (FastAPI, Uvicorn, MongoDB driver, ...) pre-installed.
Containers start instantly - none of jac's one-time setup runs at boot.

Built multi-arch (`linux/amd64`, `linux/arm64`) by
[jaseci-labs/jaseci](https://github.com/jaseci-labs/jaseci) CI from the same
binaries attached to each GitHub release.

## Tags

| Tag | Meaning |
| --- | ------- |
| `<version>` (e.g. `0.31.3`) | that jaclang release |
| `latest` | the newest release |
| `dev` | rolling build of `main` (unstable, moves on every push) |

## Usage

Check the toolchain:

```console
docker run --rm jaseci/jaclang:latest --version
```

Run a program from the current directory:

```console
docker run --rm -v "$PWD":/app jaseci/jaclang:latest run main.jac
```

Start the server for an app:

```console
docker run --rm -p 3000:3000 -v "$PWD":/app jaseci/jaclang:latest start main.jac --port 3000
```

Use as a base image:

```dockerfile
FROM jaseci/jaclang:latest
WORKDIR /app
COPY . .
RUN jac install
CMD ["jac", "start", "main.jac"]
```

This image is also the default pod base for `jac scale` Kubernetes
deployments: deploys pick the tag matching their release channel automatically
when `[scale.kubernetes].python_image` is unset.

## Source

- Website and docs: https://www.jac-lang.org
- Repository / issues: https://github.com/jaseci-labs/jaseci
- Dockerfile: https://github.com/jaseci-labs/jaseci/blob/main/docker/jaclang.Dockerfile
