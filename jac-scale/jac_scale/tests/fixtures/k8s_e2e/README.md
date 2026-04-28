# jac-shop: E-Commerce Microservice Example

Three-service e-commerce app demonstrating jac-scale microservice mode.
`orders_app` does `sv import from cart_app` to place orders, exercising
the inter-service auth-forwarding path end-to-end.

## Layout

```
micr-s-example/
  main.jac              client UI entry (cl block only)
  jac.toml              [plugins.scale.microservices] config
  products_app.jac      public: list_products, get_product
  cart_app.jac          public: add_to_cart, view_cart, remove_from_cart, clear_cart
  orders_app.jac        public: create_order, list_orders, get_order, cancel_order
                        sv imports cart_app.{view_cart, clear_cart}
  frontend.cl.jac       SPA view
  frontend.impl.jac     SPA action handlers
  components/           reusable UI components
```

## Architecture

```
Client (browser / curl)
      |
      v
Gateway :8000
  /health, /admin/, static SPA, /api/{service}/function/{name}
      |
      +--> products_app  (auto-port in 18000-18999 range)
      +--> cart_app      (auto-port)
      +--> orders_app    (auto-port)
                |
                +-- sv import from cart_app  (HTTP under the hood,
                    auth forwarded from the inbound request)
```

## Dev setup

Microservice mode lives in jac-scale 0.2.14+ and relies on a hookspec
added to jaclang core on this branch. Stable PyPI builds won't have
either yet, so install both editable from source before running:

```bash
pip install -e /path/to/jaseci/jac
pip install -e /path/to/jaseci/jac-scale
```

If `jac` isn't on your shell's PATH (common with non-activated conda
envs), pass it to the e2e script via `JAC_BIN`:

```bash
JAC_BIN=/path/to/bin/jac ./test_e2e.sh
```

Common reset commands when things go sideways:

```bash
# clear compile cache after editing a hookspec
find /path/to/jaseci -name __jac_gen__ -type d -exec rm -rf {} +

# kill leftover subprocess zombies from an interrupted run
pkill -9 -f "jac start"

# reset per-service state (sqlite + logs + pidfiles)
rm -rf .jac/data .jac/logs .jac/run
```

## Automated e2e test

```bash
./test_e2e.sh
```

Starts the stack, runs every feature below as a pass/fail check, tears
down on exit. Exit 0 if all green. The PASS/FAIL blocks map 1:1 to
intended future pytest cases. Add a new `check "..."` line whenever a
new feature lands.

## Production-hardening knobs exercised in this example

`jac.toml` enables CORS (`allow_origins = ["http://app.example.com"]`)
so `test_e2e.sh` can verify preflight + deny behavior. The remaining
knobs are referenced but left disabled to keep e2e timing independent
of bucket refills and graceful-shutdown windows:

- **Graceful drain** (P13): exercised by sending SIGTERM to a running
  service and checking the port closes within the graceful window.
- **WebSockets** (P15): exercised by `ws://localhost:8000/api/products/ws/EchoMessage`.
- **Rate limiting** (P17): covered by unit tests (`test_rate_limit.jac`),
  not e2e.
- **Per-service RPC timeout** (P14): covered by unit tests
  (`test_sv_auth_forward.jac`).

See [`../../jac_scale/microservices/docs.md`](../../jac_scale/microservices/docs.md)
for the full config reference.

## Manual test walkthrough

### 0. Pre-flight

```bash
cd jac-scale/examples/micr-s-example
pip list 2>/dev/null | grep -E "jac-scale|aiohttp|httpx|pyjwt"
rm -rf .jac/data .jac/logs
```

### 1. CLI config commands (no services needed)

```bash
jac setup microservice --list
```

Should print the routes map from `jac.toml` with `products_app`,
`cart_app`, `orders_app`.

### 2. Bring the stack up

Terminal A:

```bash
jac start main.jac
```

Wait for the banner. Three services should be marked green (healthy).
In terminal B, verify isolation:

```bash
ps -ef | grep "jac start" | grep -v grep    # 3 child subprocesses
ls .jac/data                                  # one dir per service
ls .jac/logs                                  # one .log per service
```

### 3. Gateway and static surface

```bash
curl -s http://localhost:8000/health | python3 -m json.tool
curl -sI http://localhost:8000/          | head -3   # SPA index
curl -sI http://localhost:8000/admin/    | head -3   # admin UI
```

### 4. Public function proxy (no auth required for products)

```bash
curl -s -X POST http://localhost:8000/api/products/function/list_products \
  -H 'Content-Type: application/json' -d '{}' | python3 -m json.tool
```

### 5. Built-in passthrough (register + login)

`/user/*` is proxied to whichever service exposes the endpoint. Exercises
the "try every healthy service" loop.

```bash
curl -s -X POST http://localhost:8000/user/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"alice@test.com","password":"hunter2"}'

TOKEN=$(curl -s -X POST http://localhost:8000/user/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"alice@test.com","password":"hunter2"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
echo "$TOKEN"
```

### 6. Auth-forwarding on inter-service `sv import` (the critical path)

`orders_app.create_order` calls `cart_app.view_cart` and
`cart_app.clear_cart` via `sv import`. The user's JWT must reach
cart_app on that inner hop.

```bash
# Add a product to alice's cart via the cart service directly
curl -s -X POST http://localhost:8000/api/cart/function/add_to_cart \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"product_id":"prod_1","product_name":"Wireless Headphones","price":49.99,"qty":2}' \
  | python3 -m json.tool

# Verify cart has the item
curl -s -X POST http://localhost:8000/api/cart/function/view_cart \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{}' \
  | python3 -m json.tool

# Place order: orders_app -> sv_import -> cart_app (auth must propagate)
curl -s -X POST http://localhost:8000/api/orders/function/create_order \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{}' \
  | python3 -m json.tool

# Confirm the cart was cleared (proves clear_cart() ran under alice's auth)
curl -s -X POST http://localhost:8000/api/cart/function/view_cart \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{}' \
  | python3 -m json.tool
```

**Negative test** (no auth -> downstream sv call should reject):

```bash
# Refill cart
curl -s -X POST http://localhost:8000/api/cart/function/add_to_cart \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"product_id":"prod_1","product_name":"x","price":1,"qty":1}' >/dev/null

# Call create_order with NO Authorization header
curl -s -X POST http://localhost:8000/api/orders/function/create_order \
  -H 'Content-Type: application/json' -d '{}' | python3 -m json.tool
# expected: error envelope; cart NOT cleared
```

### 7. Service-management CLI

Terminal C (with stack still running):

```bash
jac scale status                          # bullets per service
jac scale logs cart_app --lines 20        # tail the per-service log
jac scale stop cart_app                   # kill cart
# Now cart calls should fail:
curl -s -X POST http://localhost:8000/api/cart/function/view_cart \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{}'
jac scale restart cart_app                # bring it back
```

### 8. Graceful shutdown

Ctrl-C in terminal A, then:

```bash
ps -ef | grep "jac start" | grep -v grep    # should be empty
```

If any subprocess survives, `atexit` did not fire and that is a bug.
