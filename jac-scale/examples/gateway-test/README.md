# Gateway Test

Manual test for the microservice gateway with `sv import` services.

## Setup

```bash
cd jac-scale/examples/gateway-test
```

## Step 1: Start the consumer (auto-spawns math_service)

```bash
jac start calculator_service.jac --port 8002
```

This starts:
- `calculator_service` on `:8002`
- `math_service` auto-spawned on `:18xxx` (check logs for exact port)

## Step 2: Test direct (no gateway)

```bash
curl -X POST http://localhost:8002/function/sum_list \
  -H "Content-Type: application/json" \
  -d '{"numbers": [1, 2, 3, 4, 5]}'
# → 15
```

## Step 3: Start the gateway

Find the math_service port from Step 1 logs, then:

```bash
python start_gateway.py --math-port XXXXX
```

## Step 4: Test through gateway

```bash
# Calculator via gateway
curl -X POST http://localhost:8000/api/calc/function/sum_list \
  -H "Content-Type: application/json" \
  -d '{"numbers": [1, 2, 3, 4, 5]}'
# → 15

# Math directly via gateway
curl -X POST http://localhost:8000/api/math/function/add \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 20}'
# → 30

# Dot product (uses both add and multiply across services)
curl -X POST http://localhost:8000/api/calc/function/dot_product \
  -H "Content-Type: application/json" \
  -d '{"a": [1, 2, 3], "b": [4, 5, 6]}'
# → 32

# Health check
curl http://localhost:8000/health
```
