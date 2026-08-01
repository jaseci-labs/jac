# The official jaseci base image: the self-contained jac binary on a slim
# Debian base, ready to be the pod base for scale deployments. Two things are
# baked at BUILD time so containers pay neither cost at boot:
#   1. the runtime payload is extracted (pinned under XDG_CACHE_HOME so any
#      runtime HOME hits the warm path) - skips jac's one-time setup
#   2. the scale serve closure (fastapi, uvicorn, pymongo, ...) is resolved by
#      a seed `jac install` and promoted into the runtime site - pods need no
#      pip for the serving stack (installs from an init container cannot reach
#      the main container anyway: they land on the container-local runtime
#      site)
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
    && printf '[project]\nname = "seed"\nversion = "0.0.1"\nentry-point = "main.jac"\n\n[dependencies]\nsetuptools = ">=75"\n\n[serve]\nbase_route_app = "app"\n\n[scale.kubernetes]\nnamespace = "seed"\n\n[scale.database]\nbackend = "mongodb"\n' > /tmp/seed/jac.toml \
    && printf 'with entry {}\n' > /tmp/seed/main.jac \
    && (cd /tmp/seed && jac install) \
    && rt_lib=$(ls -d /opt/jac/cache/jac/rt/*/python/lib/python3.*) \
    && mkdir -p "$rt_lib/site-packages" \
    && cp -a /tmp/seed/.jac/venv/lib/python3.*/site-packages/. "$rt_lib/site-packages/" \
    && ls "$rt_lib/site-packages" | grep -q fastapi \
    && ls "$rt_lib/site-packages" | grep -q setuptools \
    && rm -rf /tmp/seed \
    && chmod -R a+rX /opt/jac/cache \
    && chmod 1777 /opt/jac/cache/jac

WORKDIR /app

ENTRYPOINT ["jac"]
CMD ["--help"]
