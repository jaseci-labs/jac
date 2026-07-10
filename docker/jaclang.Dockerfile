# The official jaclang image: the self-contained jac binary on a slim Debian
# base. The runtime payload is extracted at BUILD time (pinned under
# XDG_CACHE_HOME so any runtime HOME still hits the warm path), so containers
# skip jac's one-time setup entirely and the first command starts instantly.
#
# Built per release by .github/workflows/build-binaries.yml (docker-image job):
#   ghcr.io/jaseci-labs/jaclang:<version>  - each jaclang release
#   ghcr.io/jaseci-labs/jaclang:latest     - the newest release
#   ghcr.io/jaseci-labs/jaclang:dev        - rolling main HEAD
#
# Local build (binary for each arch under <ctx>/{amd64,arm64}/jac):
#   docker build -f docker/jaclang.Dockerfile <ctx>
FROM debian:bookworm-slim

ARG TARGETARCH

# A fixed, HOME-independent cache root: the launcher keys the extracted tree
# by (payload hash, executable path) and finds it via XDG_CACHE_HOME first,
# so the tree baked below is reused no matter which user or HOME runs jac.
ENV XDG_CACHE_HOME=/opt/jac/cache

COPY ${TARGETARCH}/jac /usr/local/bin/jac

# ca-certificates: jac downloads deps over TLS. git: [dependencies.git] installs.
# The launcher write-probes the cache root before taking the warm path, so the
# root dir must stay writable for any uid (sticky bit); the extracted tree
# itself remains read-only.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/* \
    && chmod 0755 /usr/local/bin/jac \
    && jac --version \
    && ls /opt/jac/cache/jac/rt/*/.ok \
    && chmod -R a+rX /opt/jac/cache \
    && chmod 1777 /opt/jac/cache/jac

WORKDIR /app

ENTRYPOINT ["jac"]
CMD ["--help"]
