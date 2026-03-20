FROM python:3.12-slim

RUN pip install --no-cache-dir aiohttp kubernetes_asyncio jaclang jac-scale

COPY sandbox_proxy.jac /app/sandbox_proxy.jac
WORKDIR /app

EXPOSE 8080

CMD ["jac", "run", "sandbox_proxy.jac"]
