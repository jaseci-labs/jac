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
pip install -e /path/to/jaseci/jac-scale
```

If `jac` isn't on PATH: `JAC_BIN=/path/to/bin/jac ./test_e2e.sh`.

Reset state when things go wrong:

```bash
find /path/to/jaseci -name __jac_gen__ -type d -exec rm -rf {} +
pkill -9 -f "jac start"
rm -rf .jac/data .jac/logs .jac/run
```

## Run the e2e

```bash
./test_e2e.sh
```

Starts the stack, runs every feature as a check, tears down on exit.
Exit 0 = all green. Add a new `check "..."` line whenever a new
feature lands.

See [`../../jac_scale/microservices/docs.md`](../../jac_scale/microservices/docs.md)
for the full config reference.

## Manual walkthrough

The test script (`test_e2e.sh`) is the canonical reference - read the
individual `check "..."` blocks for the exact curl invocations and
expected responses. Quick start in another terminal:

```bash
jac start main.jac                            # starts gateway + 3 services
curl http://localhost:8000/health             # gateway + service health
curl http://localhost:8000/api/products/function/list_products -X POST -d '{}'
```

Services auto-bind in the `18000-18999` range; URLs are constructed by
`LocalDeployer.url_for` and the gateway routes via the registry.
