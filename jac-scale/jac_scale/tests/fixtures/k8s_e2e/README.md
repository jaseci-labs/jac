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

## Run

```bash
jac start main.jac                            # gateway + 3 services
curl http://localhost:8000/health
curl http://localhost:8000/api/products/function/list_products -X POST -d '{}'
```

Services auto-bind in the `18000-18999` range; URLs come from
`LocalDeployer.url_for`. See [`../../../jac_scale/microservices/docs.md`](../../../jac_scale/microservices/docs.md)
for the full config reference.
