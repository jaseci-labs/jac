FROM python:3.12-slim
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
# Copy full repo including .git for submodules
COPY . /workspace/
RUN cd /workspace && git submodule update --init --recursive 2>/dev/null || true
# Install from source — compiler sees the modified .jac files during install
RUN pip install --no-cache-dir /workspace/jac/ /workspace/jac-scale/
CMD ["jac", "run", "benchmark.jac"]
