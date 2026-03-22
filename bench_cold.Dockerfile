FROM python:3.12-slim
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
COPY . /workspace/
RUN cd /workspace && git submodule update --init --recursive 2>/dev/null || true
RUN pip install --no-cache-dir /workspace/jac/ /workspace/jac-scale/
CMD ["python", "/workspace/benchmark_cold.py"]
