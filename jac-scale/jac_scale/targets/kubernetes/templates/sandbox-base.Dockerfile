FROM python:3.12-slim

# Install system deps (curl, unzip needed for bun + general use)
RUN apt-get update -qq && \
    apt-get install -y -qq curl unzip git > /dev/null 2>&1 && \
    rm -rf /var/lib/apt/lists/*

# Install Bun to /usr/local so it's accessible when running as non-root (uid 1000)
RUN curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash
ENV PATH="/usr/local/bin:$PATH"

# Install Jac ecosystem
RUN pip install --no-cache-dir jaclang jac-scale jac-client watchdog

# Pre-warm: ensure jac CLI is available
RUN jac --version

# Create non-root user for security_context (uid 1000)
RUN groupadd -g 1000 jac && useradd -u 1000 -g jac -m -s /bin/bash jac
RUN mkdir -p /app && chown 1000:1000 /app

WORKDIR /app
