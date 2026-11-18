#!/usr/bin/env bash
# Demo for #10805 / PR #10820: serve an example app with ONE worker and show
# that /metrics includes the app's own prometheus_client counter, after the fix
# and (for comparison) on main's collector.
set -uo pipefail

ROOT="$GITHUB_WORKSPACE"
APP="$ROOT/demo_10805"
OUT="$ROOT/demo_10805_out"
IMPL="jac/jaclang/scale/observability/impl/prometheus_metrics.impl.jac"
mkdir -p "$APP" "$OUT"

cat > "$APP/jac.toml" <<'EOF'
[project]
name = "shop-demo"
version = "0.1.0"

[scale.monitoring]
enabled = true
namespace = "shop_demo"
prometheus_admin_password = "scrape-secret"
EOF

cat > "$APP/main.jac" <<'EOF'
import from prometheus_client { Counter }

glob orders = Counter("shop_orders_total", "Orders placed, counted by the app itself");

def:pub place_order() -> int {
    orders.inc();
    return 1;
}
EOF

serve_and_scrape() {
    local label="$1" port="$2"
    local log="$OUT/serve-$label.log"
    (cd "$APP" && JAC_SERVE_WORKERS=1 setsid jac run --serve --port "$port" main.jac >"$log" 2>&1) &
    local up=0
    for _ in $(seq 1 300); do
        if curl -fs "http://localhost:$port/healthz" >/dev/null 2>&1; then up=1; break; fi
        sleep 1
    done
    if [ "$up" != 1 ]; then
        echo "::error::$label server never answered /healthz"; cat "$log"; return 1
    fi
    for _ in 1 2 3; do
        curl -s -X POST "http://localhost:$port/function/place_order" \
            -H 'content-type: application/json' -d '{}'; echo
    done
    curl -s -u admin:scrape-secret "http://localhost:$port/metrics" >"$OUT/metrics-$label.txt"
    if [ "$label" = "after" ]; then
        google-chrome --headless=new --no-sandbox --disable-gpu --hide-scrollbars \
            --window-size=1400,2400 --screenshot="$OUT/raw-metrics-page-after.png" \
            "http://admin:scrape-secret@localhost:$port/metrics" >/dev/null 2>&1 || true
    fi
    pkill -f "jac run --serve --port $port" || true
    sleep 2
}

serve_and_scrape after 8201

git fetch --no-tags --depth=1 origin main
git checkout FETCH_HEAD -- "$IMPL"
serve_and_scrape before 8202
git checkout HEAD -- "$IMPL"

python3 - "$OUT" <<'EOF'
import html, pathlib, sys

out = pathlib.Path(sys.argv[1])

def panel(label, title):
    text = (out / f"metrics-{label}.txt").read_text()
    lines = text.splitlines()
    app = [l for l in lines if l.startswith("shop_orders_total")]
    py_info = sum(1 for l in lines if l.startswith("# TYPE python_info "))
    shown = [
        l for l in lines
        if not l.startswith("#")
        and (l.startswith(("shop_orders", "jac_info", "python_info", "process_cpu"))
             or "place_order" in l and "requests_total" in l)
    ]
    rows = []
    for l in shown:
        cls = "app" if l.startswith("shop_orders_total") else ""
        rows.append(f'<div class="{cls}">{html.escape(l)}</div>')
    if not app:
        rows.append('<div class="missing">shop_orders_total ... MISSING</div>')
    verdict = "app counter present" if app else "app counter MISSING"
    return f"""
      <section>
        <h2>{title}</h2>
        <p class="verdict {'ok' if app else 'bad'}">{verdict}</p>
        <p>shop_orders_total lines: <b>{len(app)}</b> &nbsp; | &nbsp;
           python_info TYPE lines: <b>{py_info}</b> &nbsp; | &nbsp;
           total lines: {len(lines)}</p>
        <pre>{''.join(rows)}</pre>
      </section>"""

page = f"""<!doctype html><meta charset="utf-8"><style>
body {{ font-family: system-ui, sans-serif; margin: 24px; background: #fff; color: #111; }}
h1 {{ font-size: 22px; margin: 0 0 4px; }}
.sub {{ color: #555; margin: 0 0 18px; }}
.grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }}
section {{ border: 1px solid #ddd; border-radius: 8px; padding: 14px; }}
h2 {{ font-size: 17px; margin: 0 0 6px; }}
pre {{ font-size: 12px; background: #f6f6f6; padding: 10px; border-radius: 6px; white-space: pre-wrap; word-break: break-all; }}
.app {{ background: #d7f5dd; font-weight: 700; }}
.missing {{ background: #fbd9d9; font-weight: 700; }}
.verdict {{ font-weight: 700; margin: 0 0 6px; }}
.ok {{ color: #137333; }} .bad {{ color: #b3261e; }}
</style>
<h1>GET /metrics with JAC_SERVE_WORKERS=1, after 3 calls to place_order()</h1>
<p class="sub">App: glob orders = Counter("shop_orders_total", ...); place_order() calls orders.inc().
Relevant lines only; full bodies are in the artifact.</p>
<div class="grid">{panel("before", "Before: main's collector")}{panel("after", "After: PR #10820")}</div>
"""
(out / "compare.html").write_text(page)

summary = ["## /metrics with one worker, after 3 orders", ""]
for label in ("before", "after"):
    text = (out / f"metrics-{label}.txt").read_text()
    app = [l for l in text.splitlines() if l.startswith("shop_orders_total")]
    summary.append(f"**{label}:** `shop_orders_total` lines = {len(app)}")
    summary.extend(f"    {l}" for l in app)
    summary.append("")
print("\n".join(summary))
import os
with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as fh:
    fh.write("\n".join(summary) + "\n")
EOF

google-chrome --headless=new --no-sandbox --disable-gpu --hide-scrollbars \
    --window-size=1500,900 --screenshot="$OUT/compare-before-after.png" \
    "file://$OUT/compare.html" >/dev/null 2>&1

ls -la "$OUT"
grep -q '^shop_orders_total' "$OUT/metrics-after.txt"
