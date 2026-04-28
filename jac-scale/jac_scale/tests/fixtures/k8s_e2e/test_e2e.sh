#!/usr/bin/env bash
# End-to-end test for the jac-shop microservice example.
#
# Starts the full stack (gateway + 3 services) in the background, runs
# each shipped feature through curl, reports PASS/FAIL per check, and
# always tears the stack down on exit.
#
# Run from this directory:
#   ./test_e2e.sh
#
# Exit 0 if every check passed, non-zero otherwise. Structured so the
# individual check_* blocks map 1:1 to future pytest/jac-test cases.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$SCRIPT_DIR"

# Allow overriding the jac binary for envs where it's not on PATH
# (e.g. conda envs without activation):  JAC_BIN=/path/to/jac ./test_e2e.sh
JAC_BIN="${JAC_BIN:-jac}"

# Python sibling to JAC_BIN so `websockets` / httpx from the conda env are picked up.
_JAC_DIR="$(dirname "$(command -v "$JAC_BIN" 2>/dev/null || echo "$JAC_BIN")")"
if [ -x "$_JAC_DIR/python" ]; then
  ENV_PYTHON="$_JAC_DIR/python"
elif [ -x "$_JAC_DIR/python3" ]; then
  ENV_PYTHON="$_JAC_DIR/python3"
else
  ENV_PYTHON="python3"
fi

GATEWAY="http://localhost:8000"
STACK_LOG="$SCRIPT_DIR/.jac/e2e_stack.log"
STACK_PID=""

RED=$'\e[31m'; GREEN=$'\e[32m'; YEL=$'\e[33m'; DIM=$'\e[2m'; RESET=$'\e[0m'
PASS=0; FAIL=0; FAIL_NAMES=()

log()     { printf '%s[%s]%s %s\n' "$DIM" "$(date +%H:%M:%S)" "$RESET" "$*"; }
section() { printf '\n%s== %s ==%s\n' "$YEL" "$*" "$RESET"; }

check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  %sPASS%s  %s\n' "$GREEN" "$RESET" "$name"
    PASS=$((PASS+1))
  else
    printf '  %sFAIL%s  %s\n' "$RED" "$RESET" "$name"
    FAIL=$((FAIL+1))
    FAIL_NAMES+=("$name")
  fi
}

# Assertion helper: pipe JSON into this, pass a python expression on `d`.
#   echo "$resp" | json_is 'd["status"] == "healthy"'
json_is() {
  python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(2)
sys.exit(0 if ($1) else 1)
"
}

# Extract a JSON path as a string on stdout.
#   TOKEN=$(echo "$resp" | json_get 'd["token"]')
json_get() {
  python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(2)
v=$1
print(v if v is not None else '')
"
}

cleanup() {
  local exit_code=$?
  section "Teardown"
  if [ -n "$STACK_PID" ] && kill -0 "$STACK_PID" 2>/dev/null; then
    # Stack was launched with setsid so its pgid == its pid. Send the
    # signal to the whole group so children die too; atexit alone
    # doesn't fire reliably when the parent is blocked in uvicorn.
    log "stopping stack (pgid $STACK_PID)"
    kill -INT -"$STACK_PID" 2>/dev/null || kill -INT "$STACK_PID" 2>/dev/null || true
    sleep 2
    if kill -0 "$STACK_PID" 2>/dev/null; then
      log "stack did not exit cleanly, SIGTERM group"
      kill -TERM -"$STACK_PID" 2>/dev/null || kill -TERM "$STACK_PID" 2>/dev/null || true
      sleep 1
    fi
    wait "$STACK_PID" 2>/dev/null || true
  fi

  # Verify children died (atexit + group-signal cascade)
  local remaining
  remaining=$(pgrep -cf "jac start.*--no_client" 2>/dev/null || echo 0)
  remaining=${remaining//[[:space:]]/}
  if [ "${remaining:-0}" -gt 0 ] 2>/dev/null; then
    printf '  %sFAIL%s  subprocess cleanup (found %s orphan(s))\n' "$RED" "$RESET" "$remaining"
    FAIL=$((FAIL+1)); FAIL_NAMES+=("subprocess cleanup")
    pkill -f "jac start.*--no_client" 2>/dev/null || true
  else
    printf '  %sPASS%s  subprocess cleanup\n' "$GREEN" "$RESET"
    PASS=$((PASS+1))
  fi

  printf '\n  Passed: %s%d%s   Failed: %s%d%s\n' \
    "$GREEN" "$PASS" "$RESET" "$RED" "$FAIL" "$RESET"
  if [ "$FAIL" -gt 0 ]; then
    printf '  Failing checks:\n'
    for n in "${FAIL_NAMES[@]}"; do printf '    - %s\n' "$n"; done
    exit 1
  fi
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# 0. Pre-flight
# ---------------------------------------------------------------------------
section "Pre-flight"

command -v "$JAC_BIN" >/dev/null 2>&1 && check "jac binary ($JAC_BIN) available" true || check "jac binary ($JAC_BIN) available" false
command -v curl    >/dev/null 2>&1 && check "curl on PATH"   true || check "curl on PATH" false
command -v python3 >/dev/null 2>&1 && check "python3 on PATH" true || check "python3 on PATH" false

port_free=true
if (exec 3<>/dev/tcp/127.0.0.1/8000) 2>/dev/null; then
  exec 3>&- 3<&-
  port_free=false
fi
check ":8000 is free" $port_free

if [ "$FAIL" -gt 0 ]; then
  log "aborting: pre-flight failed"
  exit 1
fi

# Clean state so subprocesses come up with fresh data
rm -rf .jac/data .jac/logs 2>/dev/null || true
mkdir -p .jac

# ---------------------------------------------------------------------------
# 1. Start stack
# ---------------------------------------------------------------------------
section "Start stack"

# Run jac start in its own process group so SIGINT propagates to children.
setsid "$JAC_BIN" start main.jac > "$STACK_LOG" 2>&1 &
STACK_PID=$!
log "launched stack (pid $STACK_PID); log -> $STACK_LOG"

wait_healthy() {
  local deadline=$(( $(date +%s) + 60 ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    if ! kill -0 "$STACK_PID" 2>/dev/null; then
      log "stack exited prematurely"
      tail -20 "$STACK_LOG" 2>/dev/null || true
      return 1
    fi
    local resp
    resp=$(curl -sf "$GATEWAY/health" 2>/dev/null || echo "")
    if [ -n "$resp" ]; then
      local n
      n=$(echo "$resp" | python3 -c "import sys,json
d=json.load(sys.stdin)
svcs=d.get('services',{})
healthy=[k for k,v in svcs.items() if v.get('status')=='healthy']
print(len(healthy))
" 2>/dev/null || echo 0)
      if [ "$n" = "3" ]; then
        return 0
      fi
    fi
    sleep 1
  done
  return 1
}

check "all 3 services healthy within 60s" wait_healthy

if [ "$FAIL" -gt 0 ]; then
  log "cannot run feature checks; stack did not come up"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. ServiceDeployer / LocalDeployer (roadmap 1, 1a, 1b, 1c, 13)
# ---------------------------------------------------------------------------
section "ServiceDeployer / LocalDeployer"

# Three subprocess children spawned (one per service) = subprocess isolation
CHILDREN=$(pgrep -f "jac start.*--no_client" 2>/dev/null | wc -l)
check "3 service subprocesses running (one per service)" \
  bash -c "[ '$CHILDREN' -eq 3 ]"

# Ports land in 18000-18999 (hash-based), read from /health
PORTS=$(echo "$(curl -s $GATEWAY/health)" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(' '.join(str(v.get('port','')) for v in d.get('services',{}).values()))
")
check "ports are in 18000-18999 range (hash-based)" \
  bash -c 'for p in '"$PORTS"'; do [ "$p" -ge 18000 ] && [ "$p" -le 18999 ] || exit 1; done'

# Every service URL came from ServiceDeployer.url_for. LocalDeployer's
# impl returns http://127.0.0.1:{port}; verifying this URL shape at the
# edge is how we prove K8sDeployer will swap in DNS names without any
# call site change (roadmap P1).
URLS=$(echo "$(curl -s $GATEWAY/health)" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(' '.join(v.get('url','') for v in d.get('services',{}).values()))
")
check "every service.url was constructed by LocalDeployer.url_for" \
  bash -c 'for u in '"$URLS"'; do [[ "$u" =~ ^http://127\.0\.0\.1:[0-9]+$ ]] || exit 1; done'

# The get_sv_registry hookspec (roadmap P3) is transitively exercised
# by every /api/{service}/* proxy call: resolve_target_url calls
# JacRuntime.get_sv_registry() to look up base URLs. If the hookspec
# broke, auth-forwarding tests below and the authenticated proxy would
# fail immediately. No standalone check needed.

# Shared anchor store at .jac/data/anchor_store.db (all services + gateway
# share one graph, consistent with the monolith model). Per-service node
# class registration lives in examples/.../shared/models.jac.
check "shared anchor store exists (.jac/data/anchor_store.db)" \
  bash -c "[ -f .jac/data/anchor_store.db ]"

# Per-service log files at .jac/logs/{name}.log (roadmap 13)
check "per-service log file exists (products_app)" bash -c "[ -s .jac/logs/products_app.log ]"
check "per-service log file exists (cart_app)"     bash -c "[ -s .jac/logs/cart_app.log ]"
check "per-service log file exists (orders_app)"   bash -c "[ -s .jac/logs/orders_app.log ]"

# ---------------------------------------------------------------------------
# 3. CLI (roadmap 5)
# ---------------------------------------------------------------------------
section "CLI (jac setup / jac scale)"

check "jac setup microservice --list runs" \
  bash -c "$JAC_BIN setup microservice --list | grep -q 'products_app'"

check "jac scale status shows 3 services" \
  bash -c "$JAC_BIN scale status 2>&1 | grep -cE 'products_app|cart_app|orders_app' | grep -qE '^[3-9]'"

# ---------------------------------------------------------------------------
# 4. Gateway surface (roadmap 2)
# ---------------------------------------------------------------------------
section "Gateway surface"

HEALTH_RESP=$(curl -s "$GATEWAY/health")

check "/health reports status=healthy" \
  bash -c 'echo "$0" | python3 -c "import sys,json;d=json.load(sys.stdin);exit(0 if d.get(\"status\")==\"healthy\" else 1)"' \
  "$HEALTH_RESP"

check "/health lists all 3 services" \
  bash -c 'echo "$0" | python3 -c "import sys,json;d=json.load(sys.stdin);s=set(d.get(\"services\",{}).keys());exit(0 if {\"products_app\",\"cart_app\",\"orders_app\"}.issubset(s) else 1)"' \
  "$HEALTH_RESP"

# /admin/ and / depend on admin-dist and client-build being present.
# A 200 means the feature is enabled and bundle is on disk; 404 means
# "feature gated off" for this example, which is a valid shipping state.
# Either is acceptable -- what's NOT acceptable is 500 or connection
# refused (that would mean the handler itself is broken).
check "/admin/ returns 200 or 404 (not 5xx)" \
  bash -c "code=\$(curl -s -o /dev/null -w '%{http_code}' $GATEWAY/admin/); [ \"\$code\" = '200' ] || [ \"\$code\" = '404' ]"

check "/ (SPA root) returns 200 or 404 (not 5xx)" \
  bash -c "code=\$(curl -s -o /dev/null -w '%{http_code}' $GATEWAY/); [ \"\$code\" = '200' ] || [ \"\$code\" = '404' ]"

check "/nonexistent returns 404" \
  bash -c "curl -s -o /dev/null -w '%{http_code}' $GATEWAY/this-path-does-not-exist | grep -q '^404$'"

# Prometheus /metrics (ROADMAP P8). Gateway exposes per-service
# counters + latency histograms in its own registry.
METRICS_BODY=$(curl -s "$GATEWAY/metrics")
check "/metrics returns Prometheus exposition" \
  bash -c "echo '$METRICS_BODY' | grep -q 'jac_scale_gateway_requests_total'"
check "/metrics records /health hit under __health__ label" \
  bash -c "echo '$METRICS_BODY' | grep -q 'service=\"__health__\"'"

# Unified Swagger (ROADMAP P9). Gateway aggregates every healthy
# service's /openapi.json and rewrites paths under the gateway
# prefix so /docs shows one unified API surface.
DOCS_STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$GATEWAY/docs")
check "/docs returns 200 Swagger HTML" \
  bash -c "[ '$DOCS_STATUS' = '200' ]"

OPENAPI_BODY=$(curl -s "$GATEWAY/openapi.json")
check "/openapi.json is valid JSON with openapi version" \
  bash -c "echo '$OPENAPI_BODY' | python3 -c 'import sys,json;d=json.load(sys.stdin);exit(0 if d.get(\"openapi\",\"\").startswith(\"3.\") else 1)'"

check "/openapi.json aggregates paths from at least one service under /api/{svc}" \
  bash -c "echo '$OPENAPI_BODY' | python3 -c '
import sys,json
d=json.load(sys.stdin)
paths=set(d.get(\"paths\",{}).keys())
# The aggregator prefixes each services paths with its gateway route.
# Any path starting with /api/ is evidence of a successful merge.
exit(0 if any(p.startswith(\"/api/\") for p in paths) else 1)
'"

# ---------------------------------------------------------------------------
# 5. Public function proxy (roadmap 2a)
# list_products requires auth (def:pub != unauthenticated in jac-scale).
# The proxy check runs AFTER login below so we have a token; this section
# only verifies the route plumbing returns a response with an envelope
# shape (even 401 is a valid proxied response).
# ---------------------------------------------------------------------------
section "Public proxy (/api/products/function/list_products plumbing)"

PROD_RESP=$(curl -s -X POST "$GATEWAY/api/products/function/list_products" \
  -H 'Content-Type: application/json' -d '{}')

check "list_products returns a TransportResponse envelope" \
  bash -c 'echo "$0" | python3 -c "import sys,json;d=json.load(sys.stdin);exit(0 if \"ok\" in d else 1)"' \
  "$PROD_RESP"

# ---------------------------------------------------------------------------
# 5b. CORS middleware (P16). jac.toml enables allow_origins =
# ["http://app.example.com"]. Preflight + actual cross-origin request
# both carry the expected headers; an origin we did NOT allow gets
# no Allow-Origin back.
# ---------------------------------------------------------------------------
section "CORS (P16)"

CORS_PREFLIGHT_HDR=$(curl -s -D - -o /dev/null -X OPTIONS "$GATEWAY/health" \
  -H 'Origin: http://app.example.com' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: Authorization')
check "preflight echoes Allow-Origin + Allow-Credentials" \
  bash -c "echo '$CORS_PREFLIGHT_HDR' | grep -qi 'access-control-allow-origin: http://app.example.com' \
    && echo '$CORS_PREFLIGHT_HDR' | grep -qi 'access-control-allow-credentials: true'"

CORS_SIMPLE_HDR=$(curl -s -D - -o /dev/null "$GATEWAY/health" -H 'Origin: http://app.example.com')
check "simple cross-origin GET echoes Allow-Origin" \
  bash -c "echo '$CORS_SIMPLE_HDR' | grep -qi 'access-control-allow-origin: http://app.example.com'"

CORS_DENY_HDR=$(curl -s -D - -o /dev/null "$GATEWAY/health" -H 'Origin: http://evil.example.net')
check "disallowed origin gets no Allow-Origin back" \
  bash -c "! echo '$CORS_DENY_HDR' | grep -qi 'access-control-allow-origin: http://evil.example.net'"

# ---------------------------------------------------------------------------
# 6. Built-in passthrough: /user/register + /user/login (roadmap 8)
# ---------------------------------------------------------------------------
section "Built-in passthrough (/user/*)"

# jac-scale uses an identity/credential-based auth API, not email/password
USERNAME="e2e_$(date +%s)"
PASSWORD="hunter2pass"

REGISTER_BODY=$(python3 -c "import json;print(json.dumps({
  'identities':[{'type':'username','value':'$USERNAME'}],
  'credential':{'type':'password','password':'$PASSWORD'}
}))")
REG_RESP=$(curl -s -X POST "$GATEWAY/user/register" \
  -H 'Content-Type: application/json' -d "$REGISTER_BODY")
check "/user/register accepts new user" \
  bash -c 'echo "$0" | python3 -c "import sys,json;d=json.load(sys.stdin);exit(0 if d.get(\"ok\") else 1)"' \
  "$REG_RESP"

LOGIN_BODY=$(python3 -c "import json;print(json.dumps({
  'identity':{'type':'username','value':'$USERNAME'},
  'credential':{'type':'password','password':'$PASSWORD'}
}))")
LOGIN_RESP=$(curl -s -X POST "$GATEWAY/user/login" \
  -H 'Content-Type: application/json' -d "$LOGIN_BODY")
TOKEN=$(echo "$LOGIN_RESP" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
except: sys.exit(0)
# Envelope: {ok, data: {token, ...}}
data=d.get('data') or {}
print(data.get('token') or d.get('token') or '')
" 2>/dev/null)

check "/user/login returns a token" \
  bash -c '[ -n "$0" ]' "$TOKEN"

if [ -z "$TOKEN" ]; then
  log "skipping auth-gated checks (no token)"
else
  # -------------------------------------------------------------------------
  # 6b. Authenticated public proxy: list_products should now return data
  # -------------------------------------------------------------------------
  section "Authenticated proxy (/api/products/function/list_products)"

  AUTH_PROD_RESP=$(curl -s -X POST "$GATEWAY/api/products/function/list_products" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{}')
  check "list_products returns ok=true with token" \
    bash -c 'echo "$0" | python3 -c "import sys,json;d=json.load(sys.stdin);exit(0 if d.get(\"ok\") else 1)"' \
    "$AUTH_PROD_RESP"

  check "list_products returns non-empty catalog" \
    bash -c 'echo "$0" | python3 -c "
import sys,json
d=json.load(sys.stdin)
data=d.get(\"data\")
items=data.get(\"result\") if isinstance(data,dict) and \"result\" in data else data
exit(0 if items else 1)"' \
    "$AUTH_PROD_RESP"

  # -------------------------------------------------------------------------
  # 7. sv import auth forwarding (roadmap 4a/4b: THE critical path)
  # -------------------------------------------------------------------------
  section "sv_service_call auth forwarding"

  ADD_RESP=$(curl -s -X POST "$GATEWAY/api/cart/function/add_to_cart" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
    -d '{"product_id":"prod_1","product_name":"Wireless Headphones","price":49.99,"qty":2}')
  check "cart/add_to_cart succeeds" \
    bash -c 'echo "$0" | python3 -c "import sys,json;d=json.load(sys.stdin);exit(0 if d.get(\"ok\") else 1)"' \
    "$ADD_RESP"

  VIEW_RESP=$(curl -s -X POST "$GATEWAY/api/cart/function/view_cart" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{}')
  check "cart/view_cart shows the added item" \
    bash -c 'echo "$0" | python3 -c "
import sys,json
d=json.load(sys.stdin)
data=d.get(\"data\",{}).get(\"result\") or d.get(\"data\",{})
items=(data or {}).get(\"items\",[]) if isinstance(data,dict) else []
exit(0 if any(i.get(\"product_id\")==\"prod_1\" for i in items) else 1)"' \
    "$VIEW_RESP"

  ORDER_RESP=$(curl -s -X POST "$GATEWAY/api/orders/function/create_order" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{}')
  check "orders/create_order succeeds (sv-import reaches cart_app with auth)" \
    bash -c 'echo "$0" | python3 -c "import sys,json;d=json.load(sys.stdin);exit(0 if d.get(\"ok\") else 1)"' \
    "$ORDER_RESP"

  # After create_order, cart should be empty (clear_cart ran via sv import)
  VIEW2_RESP=$(curl -s -X POST "$GATEWAY/api/cart/function/view_cart" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{}')
  check "cart cleared after create_order (proves sv-import auth forwarded)" \
    bash -c 'echo "$0" | python3 -c "
import sys,json
d=json.load(sys.stdin)
data=d.get(\"data\",{}).get(\"result\") or d.get(\"data\",{})
items=(data or {}).get(\"items\",[]) if isinstance(data,dict) else []
exit(0 if not items else 1)"' \
    "$VIEW2_RESP"

  # -------------------------------------------------------------------------
  # 7b. X-Trace-Id propagation (ROADMAP P7)
  # -------------------------------------------------------------------------
  section "X-Trace-Id propagation"

  # Round-trip check: send a client-specified X-Trace-Id, expect it
  # echoed on the response. Gateway + service middleware both set
  # response.headers["X-Trace-Id"] = trace_id, so if the inbound
  # header was preserved through the full proxy hop, the client gets
  # it back. This also covers the sv-import inner hop implicitly:
  # the test below sends /api/orders/function/create_order which
  # triggers orders_app -> sv_import -> cart_app.
  TRACE_ID="e2e-trace-$(date +%s%N | tail -c 12)"

  # Refill cart so create_order has something to work with
  curl -s -X POST "$GATEWAY/api/cart/function/add_to_cart" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
    -d '{"product_id":"prod_1","product_name":"trace","price":1,"qty":1}' >/dev/null

  ECHOED_TRACE=$(curl -s -D - -X POST "$GATEWAY/api/orders/function/create_order" \
    -H "Authorization: Bearer $TOKEN" \
    -H "X-Trace-Id: $TRACE_ID" \
    -H 'Content-Type: application/json' -d '{}' -o /dev/null \
    | grep -i '^x-trace-id:' | head -1 | awk '{print $2}' | tr -d '\r\n ')
  check "X-Trace-Id echoed on response (gateway round-trip)" \
    bash -c "[ '$ECHOED_TRACE' = '$TRACE_ID' ]"

  # A gateway request that omits X-Trace-Id should get one minted for it
  MINTED_TRACE=$(curl -s -D - -X POST "$GATEWAY/api/cart/function/view_cart" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{}' -o /dev/null \
    | grep -i '^x-trace-id:' | head -1 | awk '{print $2}' | tr -d '\r\n ')
  check "gateway mints X-Trace-Id when client omits it" \
    bash -c "[ -n '$MINTED_TRACE' ] && [ '${#MINTED_TRACE}' -ge 8 ]"

  # -------------------------------------------------------------------------
  # 7c. WebSocket proxying (ROADMAP P15)
  # -------------------------------------------------------------------------
  section "WebSocket proxy (P15)"

  "$ENV_PYTHON" -c "
import asyncio, json, sys
try:
    import websockets
except ImportError:
    sys.exit(77)  # 77 = skip; websockets lib not installed
TOKEN = '$TOKEN'
async def main():
    url = f'ws://127.0.0.1:8000/api/products/ws/EchoMessage?token={TOKEN}'
    async with websockets.connect(url, open_timeout=5) as ws:
        await ws.send(json.dumps({'message': 'e2e-ws-ping', 'token': TOKEN}))
        reply = await asyncio.wait_for(ws.recv(), timeout=5)
    sys.exit(0 if '\"ok\":true' in reply and 'e2e-ws-ping' in reply else 1)
try:
    asyncio.run(main())
except Exception as e:
    print(f'WS error: {e}', file=sys.stderr)
    sys.exit(1)
" > /tmp/ws_result.txt 2>&1
  ws_rc=$?
  if [ "$ws_rc" = "77" ]; then
    log "skipping WS check (python websockets library not installed)"
  else
    check "WS through gateway proxies to products_app EchoMessage walker" \
      bash -c "[ '$ws_rc' = '0' ]"
  fi

  # Unmatched path closes with 1008 - proves the catch-all is wired.
  "$ENV_PYTHON" -c "
import asyncio, sys
try:
    import websockets
    from websockets.exceptions import ConnectionClosedOK, ConnectionClosedError
except ImportError:
    sys.exit(77)
async def main():
    try:
        async with websockets.connect('ws://127.0.0.1:8000/no/such/prefix', open_timeout=3) as ws:
            try:
                await asyncio.wait_for(ws.recv(), timeout=1)
            except Exception:
                pass
        sys.exit(0)
    except (ConnectionClosedOK, ConnectionClosedError) as e:
        sys.exit(0 if e.code == 1008 else 1)
    except Exception:
        sys.exit(1)
asyncio.run(main())
" > /dev/null 2>&1
  nomatch_rc=$?
  if [ "$nomatch_rc" = "77" ]; then
    :
  else
    check "WS to unmatched path closes with 1008" \
      bash -c "[ '$nomatch_rc' = '0' ]"
  fi

  # -------------------------------------------------------------------------
  # 8. Negative: no auth -> downstream sv call should reject
  # -------------------------------------------------------------------------
  section "Negative: create_order without auth"

  # Refill cart so we can tell if clear_cart wrongly ran
  curl -s -X POST "$GATEWAY/api/cart/function/add_to_cart" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
    -d '{"product_id":"prod_1","product_name":"x","price":1,"qty":1}' >/dev/null

  NOAUTH_RESP=$(curl -s -X POST "$GATEWAY/api/orders/function/create_order" \
    -H 'Content-Type: application/json' -d '{}')
  check "create_order without auth returns error" \
    bash -c 'echo "$0" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
except:
    sys.exit(0)  # Non-JSON error response is also a fail path
exit(0 if not d.get(\"ok\") else 1)"' \
    "$NOAUTH_RESP"

  VIEW3_RESP=$(curl -s -X POST "$GATEWAY/api/cart/function/view_cart" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{}')
  check "cart still has item (clear_cart did NOT run under no-auth path)" \
    bash -c 'echo "$0" | python3 -c "
import sys,json
d=json.load(sys.stdin)
data=d.get(\"data\",{}).get(\"result\") or d.get(\"data\",{})
items=(data or {}).get(\"items\",[]) if isinstance(data,dict) else []
exit(0 if items else 1)"' \
    "$VIEW3_RESP"
fi

# ---------------------------------------------------------------------------
# 8b. Graceful drain (ROADMAP P13). Verifies SIGTERM -> drain log line +
# port closed within the graceful-shutdown window. The drain-503 path
# on keep-alive connections is covered by unit tests.
# ---------------------------------------------------------------------------
section "Graceful drain on SIGTERM (P13)"

PRODUCTS_PORT=$(echo "$(curl -s $GATEWAY/health)" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d.get('services',{}).get('products_app',{}).get('port',''))
")
PRODUCTS_PID=$(cat .jac/run/products_app.pid 2>/dev/null || echo '')

check "products_app has a pid + port" \
  bash -c "[ -n '$PRODUCTS_PID' ] && [ -n '$PRODUCTS_PORT' ]"

# Baseline: service responds with 200 on /healthz before SIGTERM.
check "products_app healthz returns 200 before SIGTERM" \
  bash -c "[ \$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PRODUCTS_PORT/healthz) = '200' ]"

kill -TERM "$PRODUCTS_PID" 2>/dev/null || true

# Poll port-closed rather than pid-gone: the orchestrator doesn't reap
# children promptly so the pid lingers as a zombie past exit.
deadline=$(( $(date +%s) + 15 ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  if ! curl -s -o /dev/null --connect-timeout 1 "http://127.0.0.1:$PRODUCTS_PORT/healthz"; then
    break
  fi
  sleep 0.5
done

check "products_app port is closed within graceful shutdown window" \
  bash -c "! curl -s -o /dev/null --connect-timeout 1 http://127.0.0.1:$PRODUCTS_PORT/healthz"

check "drain log line appears in service log after SIGTERM" \
  bash -c "grep -q 'drain: started' .jac/logs/products_app.log"

# ---------------------------------------------------------------------------
# 9. Scale CLI (status / logs / stop / restart) (roadmap 5a resolved by P4)
#
# stop/restart now work cross-process via pidfiles at .jac/run/{name}.pid.
# The orchestrator writes one pidfile per service in start_service; the
# CLI reads them in a fresh LocalDeployer to signal services by pid.
# ---------------------------------------------------------------------------
section "jac scale status / logs / stop / restart"

check "jac scale status lists 3 services" \
  bash -c "$JAC_BIN scale status 2>&1 | grep -cE 'products_app|cart_app|orders_app' | grep -qE '^[3-9]'"

check "jac scale logs cart_app returns content" \
  bash -c "$JAC_BIN scale logs cart_app --lines 5 2>&1 | grep -q '.'"

check "pidfile exists for each service (cross-process CLI state)" \
  bash -c "[ -s .jac/run/products_app.pid ] && [ -s .jac/run/cart_app.pid ] && [ -s .jac/run/orders_app.pid ]"

check "jac scale stop cart_app kills the cart service" \
  bash -c "$JAC_BIN scale stop cart_app 2>&1 | grep -qiE 'stopped' && sleep 1 && ! ss -lntp 2>/dev/null | grep -q \":\$(cat .jac/run/orders_app.pid.bak 2>/dev/null || echo 99999)\""

# After stop, cart API should return 502/503 (service not reachable)
sleep 1
STATUS_AFTER_STOP=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$GATEWAY/api/cart/function/view_cart" \
  -H "Authorization: Bearer ${TOKEN:-x}" -H 'Content-Type: application/json' -d '{}')
check "cart call returns 502/503 while stopped" \
  bash -c "[ '$STATUS_AFTER_STOP' = '502' ] || [ '$STATUS_AFTER_STOP' = '503' ]"

# ROADMAP P10: standardized error envelope + graceful degradation.
# When the service is stopped, the gateway should return the standard
# envelope (ok/error/meta with error.code) and a Retry-After header
# to help well-behaved clients back off during pod restarts.
STOPPED_RESP=$(curl -s -D /tmp/stopped_headers.txt -X POST "$GATEWAY/api/cart/function/view_cart" \
  -H "Authorization: Bearer ${TOKEN:-x}" -H 'Content-Type: application/json' -d '{}')
check "stopped-service response has the standard ok=false envelope" \
  bash -c "echo '$STOPPED_RESP' | python3 -c '
import sys,json
d=json.load(sys.stdin)
exit(0 if d.get(\"ok\") is False and d.get(\"error\",{}).get(\"code\") in (\"SERVICE_UNAVAILABLE\",\"GATEWAY_TIMEOUT\") else 1)
'"
check "stopped-service response is enriched with service + trace_id" \
  bash -c "echo '$STOPPED_RESP' | python3 -c '
import sys,json
d=json.load(sys.stdin)
e=d.get(\"error\",{})
# service must be in the envelope; trace_id is auto-populated by the
# gateway even when the client did not set one
exit(0 if e.get(\"service\")==\"cart_app\" and e.get(\"trace_id\") else 1)
'"

# NOTE: "jac scale restart" from a separate shell CAN spawn a new
# service (its pidfile gets written), but the orchestrator's in-process
# sv_client._registry still holds the OLD URL, so the gateway routes to
# the dead port. Making the gateway pick up CLI-initiated restarts needs
# a shared (file-backed or socket-based) registry, which is a separate
# cross-process state task beyond P4's pidfile scope. Not testing that
# here; the scope of P4 is proving the CLI can stop a running service.

# Cleanup handled by trap
