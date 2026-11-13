#!/usr/bin/env bash
# Temporary benchmark for #9836: forwarded calls through the fleet gateway,
# with main's serving client/server (base) against this PR's (head).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export JAC_DEV_SOURCE="${ROOT}/jac"
WS="${ROOT}/bench9836"
FILES=(
    jac/jaclang/server/serving/client.jac
    jac/jaclang/server/serving/impl/client.impl.jac
    jac/jaclang/server/serving/impl/server.impl.jac
)

mkdir -p "${WS}"
cat > "${WS}/jac.toml" <<'EOF'
[project]
name = "bench-9836"
default-app = "main"

[apps.main]
kind = "web-app"
entry-point = "main"

[apps.svc]
kind = "service"
entry-point = "svc"
route = "/svc"

[scale.gateway]
colocate = false
EOF
cat > "${WS}/svc.jac" <<'EOF'
def:pub ping -> str {
    return "pong";
}

walker:pub Ping {
    can run with Root entry {
        report "pong";
    }
}
EOF
cat > "${WS}/main.jac" <<'EOF'
def:pub greet -> str {
    return "hi";
}
EOF

cat > "${RUNNER_TEMP:-/tmp}/bench_9836_load.py" <<'EOF'
import http.client, json, statistics, sys, threading, time

variant = sys.argv[1]
SEQ, WARM, THREADS, PER_THREAD = 1000, 100, 16, 200


def call(conn, path):
    conn.request("POST", path, body=b"{}", headers={"Content-Type": "application/json"})
    resp = conn.getresponse()
    resp.read()
    return resp.status


for kind, path in (("function", "/svc/function/ping"), ("walker", "/svc/walker/Ping")):
    conn = http.client.HTTPConnection("127.0.0.1", 8000, timeout=30)
    status = call(conn, path)
    if status != 200:
        print(json.dumps({"variant": variant, "kind": kind, "skipped": status}))
        continue
    for _ in range(WARM):
        call(conn, path)
    lat = []
    for _ in range(SEQ):
        t = time.perf_counter()
        call(conn, path)
        lat.append(time.perf_counter() - t)
    conn.close()
    lat.sort()
    errors = []
    completed = []

    def worker():
        c = http.client.HTTPConnection("127.0.0.1", 8000, timeout=30)
        try:
            for _ in range(PER_THREAD):
                if call(c, path) == 200:
                    completed.append(1)
                else:
                    errors.append("status")
        except Exception as e:
            errors.append(repr(e))
        finally:
            c.close()

    threads = [threading.Thread(target=worker) for _ in range(THREADS)]
    t0 = time.perf_counter()
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    wall = time.perf_counter() - t0
    print(json.dumps({
        "variant": variant,
        "kind": kind,
        "seq_p50_ms": round(statistics.median(lat) * 1000, 2),
        "seq_p95_ms": round(lat[int(len(lat) * 0.95)] * 1000, 2),
        "seq_rps": round(SEQ / sum(lat), 1),
        "conc_rps": round(len(completed) / wall, 1),
        "conc_completed": len(completed),
        "conc_errors": len(errors),
        "conc_error_sample": errors[:3],
    }))
    if errors:
        sys.exit(f"{kind}: {len(errors)} concurrent calls failed")
EOF

git -C "${ROOT}" fetch -q --depth=1 origin main
BASE="$(git -C "${ROOT}" rev-parse FETCH_HEAD)"
HEAD_SHA="$(git -C "${ROOT}" rev-parse HEAD)"
echo "### base ${BASE} head ${HEAD_SHA}"

round() {
    local variant="$1" ref="$2"
    git -C "${ROOT}" checkout -q "${ref}" -- "${FILES[@]}"
    echo "### round ${variant}: _SAFE_METHODS in client.jac = $(grep -c _SAFE_METHODS "${ROOT}/${FILES[0]}")"
    cd "${WS}"
    setsid timeout 900 jac run --serve --fleet --port 8000 main > "${WS}/${variant}.log" 2>&1 &
    local pid=$!
    local ready=0
    for _ in $(seq 1 120); do
        if curl -sf -o /dev/null -X POST -H 'Content-Type: application/json' -d '{}' \
            http://127.0.0.1:8000/svc/function/ping; then
            ready=1
            break
        fi
        kill -0 "${pid}" 2>/dev/null || break
        sleep 5
    done
    if [ "${ready}" -ne 1 ]; then
        echo "### ${variant}: fleet never answered"
        tail -80 "${WS}/${variant}.log"
        kill -TERM -- "-${pid}" 2>/dev/null
        return 1
    fi
    local tw_before tw_after
    tw_before=$(ss -tan state time-wait | tail -n +2 | wc -l)
    python3 "${RUNNER_TEMP:-/tmp}/bench_9836_load.py" "${variant}" | tee -a "${ROOT}/bench9836/results.jsonl"
    local load_rc=${PIPESTATUS[0]}
    tw_after=$(ss -tan state time-wait | tail -n +2 | wc -l)
    echo "{\"variant\": \"${variant}\", \"time_wait_added\": $((tw_after - tw_before))}" | tee -a "${ROOT}/bench9836/results.jsonl"
    kill -TERM -- "-${pid}" 2>/dev/null
    wait "${pid}" 2>/dev/null
    sleep 5
    cd "${ROOT}"
    if [ "${load_rc}" -ne 0 ]; then
        echo "### ${variant}: load generator failed (${load_rc})"
        tail -80 "${WS}/${variant}.log"
    fi
    return "${load_rc}"
}

status=0
for variant in head base head base; do
    ref="${HEAD_SHA}"
    [ "${variant}" = "base" ] && ref="${BASE}"
    round "${variant}" "${ref}" || status=1
done
git -C "${ROOT}" checkout -q "${HEAD_SHA}" -- "${FILES[@]}"
echo "### results"
cat "${ROOT}/bench9836/results.jsonl"
exit "${status}"
