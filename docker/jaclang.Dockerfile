# The official jaseci base image: the self-contained jac binary on a slim
# Debian base, ready to be the pod base for scale deployments. Four things are
# baked at BUILD time so containers pay neither cost nor network at boot:
#   1. the runtime payload is extracted (pinned under XDG_CACHE_HOME so any
#      runtime HOME hits the warm path) - skips jac's one-time setup
#   2. the scale serve closure (python-dotenv; the Postgres driver is vendored
#      with the runtime) is resolved by a seed `jac install` and promoted into
#      the runtime site - pods need no pip for the serving stack (installs
#      from an init container cannot reach the main container anyway: they
#      land on the container-local runtime site)
#   3. the embedded Postgres distribution (`jac db fetch` -> JAC_PG_DIST), so a
#      program that does touch the graph never downloads ~40MB at container
#      start and works in an air-gapped or registry-only cluster
#   4. a real unprivileged account (uid/gid 1000) that the image defaults to:
#      initdb refuses to run as root, and it also refuses a uid with no
#      /etc/passwd entry, so `runAsUser: 1000` matches this account instead
#      of failing to resolve
#
# Built per release by .github/workflows/build-binaries.yml (docker-image job):
#   jaseci/jaclang:<version>  - each jaclang release
#   jaseci/jaclang:latest     - the newest release
#   jaseci/jaclang:dev        - rolling main HEAD
#
# Local build (binary for each arch under <ctx>/{amd64,arm64}/jac):
#   docker build -f docker/jaclang.Dockerfile <ctx>
# trixie's glibc (2.41) covers both channels: release binaries carry a 2.17
# floor, but dev-channel binaries build host-native on ubuntu-24.04 (2.39)
# and fail on bookworm's 2.36.
FROM debian:trixie-slim

ARG TARGETARCH

# A fixed, HOME-independent cache root: the launcher keys the extracted tree
# by (payload hash, executable path) and finds it via XDG_CACHE_HOME first,
# so the tree baked below is reused no matter which user or HOME runs jac.
ENV XDG_CACHE_HOME=/opt/jac/cache

# jac's own runtime state (the embedded Postgres cluster) is keyed off
# JAC_CACHE_HOME, which otherwise follows HOME. Pin it to a shared sticky
# directory so any uid the pod runs as can provision a cluster, and so an
# operator who mounts a volume has one path to mount.
ENV JAC_CACHE_HOME=/opt/jac/state

COPY ${TARGETARCH}/jac /usr/local/bin/jac

# ca-certificates: jac downloads deps over TLS. git: [dependencies.git] installs.
# The seed project carries scale intent, so its `jac install` resolves the
# serve capability closure via jac's own logic. The standalone binary installs
# into the seed project's .jac/venv (created from the runtime's bundled
# CPython - same interpreter, same ABI), so the venv's site-packages is then
# promoted into the runtime site, where the embedded interpreter imports from
# at serve time - pods pay no pip at boot. setuptools lands there too: the
# seed declares it (>=75) and venv creation seeds the build backend - in-pod
# installs of any dependency lacking a wheel for this Python fall back to an
# sdist build that needs setuptools.build_meta - pip fails the whole install
# without it. The launcher write-probes the cache root before taking the warm
# path, so the root dir must stay writable for any uid (sticky bit); the tree
# itself stays read-only.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/* \
    && chmod 0755 /usr/local/bin/jac \
    && jac --version \
    && ls /opt/jac/cache/jac/rt/*/.ok \
    && mkdir /tmp/seed \
    && printf '[project]\nname = "seed"\nversion = "0.0.1"\nentry-point = "main.jac"\n\n[dependencies]\nsetuptools = ">=75"\n\n[scale.kubernetes]\nnamespace = "seed"\n' > /tmp/seed/jac.toml \
    && printf 'with entry {}\n' > /tmp/seed/main.jac \
    && (cd /tmp/seed && jac install) \
    && rt_lib=$(ls -d /opt/jac/cache/jac/rt/*/python/lib/python3.*) \
    && mkdir -p "$rt_lib/site-packages" \
    && cp -a /tmp/seed/.jac/venv/lib/python3.*/site-packages/. "$rt_lib/site-packages/" \
    && ls "$rt_lib/site-packages" | grep -q dotenv \
    && ls "$rt_lib/site-packages" | grep -q setuptools \
    && rm -rf /tmp/seed \
    && chmod -R a+rX /opt/jac/cache \
    && chmod 1777 /opt/jac/cache/jac

# `jac db fetch` runs the runtime's own resolution chain (pinned major, newest
# published fallback, checksum-verified download) so the version pin lives in
# one place. The dist lands in the cache; move it to a stable path any uid can
# read and pin JAC_PG_DIST at it, which short-circuits every later lookup.
RUN jac db fetch \
    && mv "$(ls -d /opt/jac/state/pg/dist/*/)" /opt/jac/pg \
    && rm -rf /opt/jac/state/pg \
    && chmod -R a+rX /opt/jac/pg \
    && test -x /opt/jac/pg/bin/initdb \
    && test -x /opt/jac/pg/bin/postgres

ENV JAC_PG_DIST=/opt/jac/pg

# A real account, not just a numeric USER: initdb fails with "could not look
# up effective user ID" for a uid absent from /etc/passwd, so the uid pods are
# most likely to request (1000) is the one created here.
RUN groupadd --gid 1000 jac \
    && useradd --uid 1000 --gid 1000 --create-home --shell /bin/sh jac \
    && mkdir -p /app /opt/jac/state \
    && chown 1000:1000 /app \
    && chmod 1777 /opt/jac/state

WORKDIR /app
USER jac

ENTRYPOINT ["jac"]
CMD ["--help"]
