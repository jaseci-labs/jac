FROM python:3.12-slim
WORKDIR /workspace
COPY jac/ /workspace/jac/
RUN pip install --no-cache-dir /workspace/jac/
COPY benchmark.jac /workspace/
# For jac-scale mode
ARG INSTALL_SCALE=false
COPY jac-scale/ /workspace/jac-scale/
RUN if [ "$INSTALL_SCALE" = "true" ]; then pip install --no-cache-dir /workspace/jac-scale/; fi
CMD ["jac", "run", "benchmark.jac"]
