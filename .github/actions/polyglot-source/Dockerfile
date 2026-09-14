FROM node:22-bookworm-slim AS node
FROM python:3.14-trixie
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key -o /usr/share/keyrings/llvm.asc \
    && echo 'deb [signed-by=/usr/share/keyrings/llvm.asc] https://apt.llvm.org/trixie/ llvm-toolchain-trixie-22 main' > /etc/apt/sources.list.d/llvm.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends clang-22 lld-22 wasi-libc libclang-rt-22-dev-wasm32 \
    && rm -rf /var/lib/apt/lists/*
ENV CC=clang-22 WASI_SYSROOT=/usr PYTHONUNBUFFERED=1
WORKDIR /app
