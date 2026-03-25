# Use Python 3.12 slim image as base
FROM --platform=$BUILDPLATFORM python:3.12-slim

# Set working directory
WORKDIR /app

# Set environment variables for production
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    unzip && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir jaclang jac-scale jac-client jac-super

# Install Bun (required for jac install npm dependencies)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

COPY jac.toml* ./

RUN if [ -f jac.toml ]; then jac install; fi

COPY . .
