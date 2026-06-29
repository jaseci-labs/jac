# jac-shop: E-Commerce Microservice Example

Three-service demo for jac-scale microservice mode. `orders_app` does
`sv import from cart_app` to exercise the inter-service auth-forwarding
path end-to-end.

```
micr-s-example/
  main.jac              client UI entry (cl block only)
  jac.toml              [plugins.scale.microservices] config
  products_app.jac      list_products, get_product
  cart_app.jac          add_to_cart, view_cart, remove_from_cart, clear_cart
  orders_app.jac        create_order, list_orders, get_order, cancel_order
                        sv imports cart_app.{view_cart, clear_cart}
  frontend.cl.jac       SPA view
  components/           reusable UI components
```

Gateway `:8000` fronts all three services; `/api/{svc}/function/{name}`
forwards to the matching service. The client (browser/curl) only talks
to the gateway.

## Dev setup

Microservice mode lives in jac-scale 0.2.14+ and depends on a hookspec
that isn't on PyPI yet. Editable install both:

```bash
pip install -e /path/to/jaseci/jac
jac install -e /path/to/jaseci/jac-scale
```

## Run

```bash
jac start main.jac                            # gateway + 3 services
curl http://localhost:8000/health
curl http://localhost:8000/api/products/function/list_products -X POST -d '{}'
```

Services auto-bind in the `18000-18999` range; URLs come from
`LocalDeployer.url_for`. See [`../../../jac_scale/runtime/docs.md`](../../../jac_scale/runtime/docs.md)
for the full config reference.

## Real K8s e2e (incl. M-14.a observability stack)

The fixture's `jac.toml` has `[plugins.scale.microservices.logs].enabled = true`,
so [`../../../scripts/k8s_microservice_real_e2e.sh`](../../../scripts/k8s_microservice_real_e2e.sh)
will additionally deploy Prometheus + Grafana + Loki + Alloy + node-exporter

+ kube-state-metrics, wait for them to be Ready, and run a LogQL probe
to confirm Alloy is shipping pod logs to Loki.

### EC2 sizing

The full stack is **~12 pods** (gateway + 3 services + Mongo + Redis

+ 6 observability). Minimum:

| Resource | Min | Comfortable |
|----------|-----|-------------|
| Instance | `t3.xlarge` (4 vCPU / 16 GiB) | `t3.2xlarge` (8 vCPU / 32 GiB) |
| EBS root | 50 GiB gp3 | 100 GiB gp3 |
| OS | Ubuntu 22.04 LTS | same |

### Setup

```bash
# Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER && newgrp docker

# kubectl + minikube
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/ && rm kubectl
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

# Python + editable jaseci install
sudo apt update && sudo apt install -y python3-pip python3-venv git
git clone https://github.com/jaseci-labs/jaseci.git
cd jaseci
pip install -e ./jac
jac install -e ./jac-scale

# Start minikube with enough headroom for the full stack
minikube start --driver=docker --cpus=4 --memory=12g
minikube addons enable ingress metrics-server
```

### Run

```bash
cd ~/jaseci
bash jac-scale/scripts/k8s_microservice_real_e2e.sh \
     jac-scale/jac_scale/tests/fixtures/k8s_e2e
```

Expected runtime on `t3.xlarge`: 8-15 min for a cold run
(host binary build + pod boot dominates). The script ends with
`=== K8s microservice REAL e2e PASSED ===` on success.

### What the M-14.a phase asserts

After the existing /health + routing checks pass:

1. **Rollouts**: `<app>-loki`, `<app>-prometheus`, `<app>-grafana`
   Deployments + `<app>-alloy` DaemonSet all reach Ready within
   5 / 3 min respectively.
2. **Loki readiness**: port-forward `<app>-loki-service:3100`, retry
   `GET /ready` until 200 (within 30s).
3. **LogQL probe**: after 15 s for Alloy to discover + ship initial
   logs, query `{namespace="<ns>"}` and require >=1 stream. Retries
   for 50 s before failing.

Cleanup runs unconditionally (trap on EXIT) and additionally deletes
the cluster-scoped Alloy `ClusterRole` + `ClusterRoleBinding` so reruns
don't leak them.
