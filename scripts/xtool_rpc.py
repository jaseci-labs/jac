#!/usr/bin/env python3
"""Cross-tool RPC *verdict* producer for JacInteropBench (family-2 seam).

The paper's family-2 cells characterise Jac's generated `cl->sv` / `sv-import`
RPC crossing but give it no hand-written comparand: a cost without a verdict.
This script supplies the verdict matrix the Related Work / Conclusion defers --
the SAME `charge_card` checksum computed over the SAME sequential-call workload,
crossed five ways:

  * direct_inproc  -- pure in-process call (no crossing; the floor).
  * jac_direct     -- Jac in-process baseline (`jac run direct_runner.jac`).
  * jac_sv         -- Jac's SHIPPED path: `jac start billing.jac` app server +
                      `sv import` client (`rpc_runner.jac`). The number the
                      paper's 374x/241x ratios come from.
  * fastapi_httpx  -- hand-written glue: a FastAPI/uvicorn server exposing the
                      same endpoint + a persistent-connection httpx client loop.
  * fastapi_openapi-- the same server driven through a generated-client-equivalent
                      layer (pydantic request/response model validation over
                      httpx -- the per-call overhead an OpenAPI code generator
                      like openapi-python-client emits).
  * minimal_http   -- control: a bare stdlib `http.server` one-route endpoint +
                      keep-alive `http.client` loop (the RPC-physics floor the
                      rpc_floor_probe isolated).

Two measurements per comparand mirror tab:xtool:
  * MATCHED  -- per-call cost at the kernel's real work size W.
  * ISOLATED -- per-call cost at work=1, where the callee arithmetic is
                negligible and the number is boundary (framework dispatch +
                client marshalling), the family-2 analog of the FFI isolated
                column and the rpc_floor_probe decomposition.

RTT: every comparand records a TCP-connect RTT to its provider (median of
--rtt-samples connects). By default the providers are SELF-HOSTED on loopback
(127.0.0.1, a free port), so this RTT is tens of microseconds -- confirming the
~15 ms floor is framework+marshalling, not wire, exactly as rpc_floor_probe
found. The default canonical numbers are therefore loopback numbers.

REAL cross-machine RTT (two-box mode): start a provider on machine B with
    scripts/.xtool-venv/bin/python scripts/xtool_rpc.py --serve fastapi --port 9000
    scripts/.xtool-venv/bin/python scripts/xtool_rpc.py --serve minimal --port 9001
    (jac_sv: `jac start billing.jac --port 9002` in kernels/xop_svc_split)
then drive from machine A with
    ... --provider-host B.B.B.B --provider-port 9000 --minimal-port 9001 \
        --jac-sv-url http://B.B.B.B:9002 --comparands fastapi_httpx,minimal_http,jac_sv
In two-box mode the client does NOT launch a local server; it connects to the
remote and the RTT term is a real-network RTT. The wire term is always reported
separately so marshalling and network are never conflated. (Previously
--provider-host was inert: the server was still spawned locally on a random
port, so a remote host pointed at nothing -- interop-bench#9.)

Every comparand recomputes one byte-identical digest `charge:<checksum>`; the
run ABORTS if any disagree.

Run under the venv that has fastapi/httpx/uvicorn:
    scripts/.xtool-venv/bin/python scripts/xtool_rpc.py --work 5000 --calls 200 \
        --reps 3 --out results/controlled/xtool_rpc.json
"""

from __future__ import annotations

import argparse
import http.client
import json
import re
import shutil
import socket
import statistics
import subprocess
import sys
import tempfile
import time
from collections.abc import Callable
from contextlib import closing
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BENCH = ROOT / "jac" / "examples" / "interopbench"
SVC = BENCH / "kernels" / "xop_svc_split"

WARMUP_CALLS = 5


def is_loopback(host: str) -> bool:
    return host in ("127.0.0.1", "localhost", "::1")


# ---------------------------------------------------------------------------
# The kernel arithmetic, byte-identical to billing.jac / *_runner.jac.
# ---------------------------------------------------------------------------
def charge_card(seed: int, work: int) -> int:
    value = seed
    for i in range(work):
        value = (value * 1103515245 + 12345 + i) % 2147483648
    return value


def checksum(work: int, calls: int) -> int:
    cs = 0
    for call_no in range(calls):
        cs = (cs + charge_card(call_no + 1, work)) % 2147483648
    return cs


PER_RE = re.compile(rb"m:per_call_ns=(\d+)")
CHARGE_RE = re.compile(rb"(charge:\d+)")


def median_reps(fn: Callable[[], float], reps: int) -> float:
    return statistics.median([fn() for _ in range(reps)])


# ---------------------------------------------------------------------------
# Server lifecycle.
# ---------------------------------------------------------------------------
def free_port() -> int:
    with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
        s.bind(("", 0))
        return s.getsockname()[1]


def wait_ready(
    check: Callable[[], bool], timeout_s: float, log_path: Path | None = None
) -> None:
    deadline = time.time() + timeout_s
    last = None
    while time.time() < deadline:
        try:
            if check():
                return
        except Exception as e:  # noqa: BLE001
            last = e
        time.sleep(0.25)
    tail = ""
    if log_path and log_path.exists():
        tail = "\n".join(log_path.read_text().splitlines()[-15:])
    raise RuntimeError(f"provider not ready after {timeout_s}s: {last}\n{tail}")


def http_ok(host: str, port: int, path: str) -> bool:
    c = http.client.HTTPConnection(host, port, timeout=2)
    try:
        c.request("GET", path)
        return c.getresponse().status == 200
    finally:
        c.close()


def tcp_rtt_ns(host: str, port: int, samples: int) -> dict:
    """Median TCP connect time -> the network/transport RTT term."""
    xs = []
    for _ in range(samples):
        t0 = time.perf_counter_ns()
        try:
            with closing(socket.create_connection((host, port), timeout=2)):
                pass
        except OSError:
            continue
        xs.append(time.perf_counter_ns() - t0)
    if not xs:
        return {"median_ns": None, "n": 0}
    return {
        "median_ns": statistics.median(xs),
        "min_ns": min(xs),
        "max_ns": max(xs),
        "n": len(xs),
    }


# ---------------------------------------------------------------------------
# Comparand: Jac subprocess runners (direct + shipped sv path).
# ---------------------------------------------------------------------------
def run_jac_runner(
    runner: str, work: int, calls: int, env: dict | None, reps: int
) -> dict:
    jac = shutil.which("jac")
    if jac is None:
        return {"skipped": "jac not on PATH"}
    cmd = [jac, "run", runner, str(work), str(calls)]

    def once() -> tuple:
        p = subprocess.run(
            cmd,
            cwd=str(SVC),
            capture_output=True,
            timeout=600,
            env=({**_os_environ(), **env} if env else None),
        )
        per = PER_RE.search(p.stdout)
        dig = CHARGE_RE.search(p.stdout)
        return (
            int(per.group(1)) if per else None,
            dig.group(1).decode() if dig else None,
        )

    pers, digs = [], set()
    for _ in range(reps):
        per, dig = once()
        if per is not None:
            pers.append(per)
        if dig:
            digs.add(dig)
    if not pers:
        return {"skipped": f"{runner} produced no m:per_call_ns"}
    return {
        "per_call_ns": statistics.median(pers),
        "samples": pers,
        "digest": digs.pop() if len(digs) == 1 else list(digs),
    }


def _os_environ() -> dict:
    import os

    return dict(os.environ)


# ---------------------------------------------------------------------------
# FastAPI server (written to temp, launched with THIS interpreter/uvicorn).
# ---------------------------------------------------------------------------
FASTAPI_SERVER = r"""
import sys
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

def charge_card(seed: int, work: int) -> int:
    value = seed
    for i in range(work):
        value = (value * 1103515245 + 12345 + i) % 2147483648
    return value

class Req(BaseModel):
    seed: int
    work: int

app = FastAPI()

@app.get("/healthz")
def healthz():
    return {"ok": True}

@app.post("/function/charge_card")
def charge(body: Req):
    return {"ok": True, "data": {"result": charge_card(body.seed, body.work)}}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(sys.argv[1]), log_level="warning")
"""

MINIMAL_SERVER = r"""
import sys, json, socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

def charge_card(seed, work):
    value = seed
    for i in range(work):
        value = (value * 1103515245 + 12345 + i) % 2147483648
    return value

class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def setup(self):
        super().setup()
        # disable Nagle: without this, header+body split writes stall on
        # loopback delayed-ACK (~40ms/call), swamping the measurement.
        self.connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    def log_message(self, *a): pass
    def do_GET(self):
        if self.path == "/healthz":
            b = b'{"ok":true}'
            self.send_response(200); self.send_header("Content-Length", str(len(b)))
            self.end_headers(); self.wfile.write(b)
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        req = json.loads(self.rfile.read(n))
        r = charge_card(req["seed"], req["work"])
        b = json.dumps({"result": r}).encode()
        self.send_response(200); self.send_header("Content-Length", str(len(b)))
        self.send_header("Content-Type", "application/json"); self.end_headers()
        self.wfile.write(b)

ThreadingHTTPServer(("0.0.0.0", int(sys.argv[1])), H).serve_forever()
"""


class Server:
    def __init__(self, source: str, port: int, workdir: Path, name: str):
        self.port = port
        self.log = workdir / f"{name}.log"
        # prefix avoids shadowing real packages (a bare fastapi.py would mask
        # the fastapi package on import).
        script = workdir / f"ib_srv_{name}.py"
        script.write_text(source)
        self._logf = self.log.open("w")
        self.proc = subprocess.Popen(
            [sys.executable, str(script), str(port)],
            stdout=self._logf,
            stderr=subprocess.STDOUT,
        )

    def __enter__(self) -> Server:
        wait_ready(lambda: http_ok("127.0.0.1", self.port, "/healthz"), 30, self.log)
        return self

    def __exit__(self, *exc: object) -> None:
        self.proc.terminate()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
        self._logf.close()


# ---------------------------------------------------------------------------
# HTTP clients. Each does WARMUP then times `calls` sequential calls, returning
# per-call ns + digest. Persistent connection (keep-alive) throughout.
# ---------------------------------------------------------------------------
def client_httpx(
    host: str,
    port: int,
    path: str,
    work: int,
    calls: int,
    unwrap: Callable[[dict], int],
    reps: int,
) -> dict:
    import httpx

    base = f"http://{host}:{port}"
    with httpx.Client(base_url=base, timeout=30) as cx:
        for _ in range(WARMUP_CALLS):
            cx.post(path, json={"seed": 1, "work": work})

        def once() -> tuple:
            cs = 0
            for call_no in range(calls):
                r = cx.post(path, json={"seed": call_no + 1, "work": work})
                cs = (cs + unwrap(r.json())) % 2147483648
            return cs

        pers, digs = [], set()
        for _ in range(reps):
            t0 = time.perf_counter_ns()
            cs = once()
            pers.append((time.perf_counter_ns() - t0) / calls)
            digs.add(f"charge:{cs}")
    return {
        "per_call_ns": statistics.median(pers),
        "digest": digs.pop() if len(digs) == 1 else list(digs),
    }


def client_openapi_equiv(
    host: str, port: int, path: str, work: int, calls: int, reps: int
) -> dict:
    """Generated-client-equivalent: validate every request+response through
    pydantic models, the per-call cost an OpenAPI generator's typed client
    imposes on top of the raw transport."""
    import httpx
    from pydantic import BaseModel

    class ChargeRequest(BaseModel):
        seed: int
        work: int

    class ChargeData(BaseModel):
        result: int

    class ChargeResponse(BaseModel):
        ok: bool
        data: ChargeData

    base = f"http://{host}:{port}"
    with httpx.Client(base_url=base, timeout=30) as cx:
        for _ in range(WARMUP_CALLS):
            cx.post(path, json=ChargeRequest(seed=1, work=work).model_dump())

        def once() -> int:
            cs = 0
            for call_no in range(calls):
                body = ChargeRequest(seed=call_no + 1, work=work).model_dump()
                r = cx.post(path, json=body)
                parsed = ChargeResponse.model_validate(r.json())
                cs = (cs + parsed.data.result) % 2147483648
            return cs

        pers, digs = [], set()
        for _ in range(reps):
            t0 = time.perf_counter_ns()
            cs = once()
            pers.append((time.perf_counter_ns() - t0) / calls)
            digs.add(f"charge:{cs}")
    return {
        "per_call_ns": statistics.median(pers),
        "digest": digs.pop() if len(digs) == 1 else list(digs),
    }


def client_minimal(host: str, port: int, work: int, calls: int, reps: int) -> dict:
    """Keep-alive http.client loop against the bare endpoint."""

    def connect() -> http.client.HTTPConnection:
        c = http.client.HTTPConnection(host, port, timeout=30)
        c.connect()
        c.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        return c

    def once() -> int:
        c = connect()
        cs = 0
        for call_no in range(calls):
            body = json.dumps({"seed": call_no + 1, "work": work}).encode()
            c.request("POST", "/charge", body, {"Content-Type": "application/json"})
            resp = c.getresponse()
            cs = (cs + json.loads(resp.read())["result"]) % 2147483648
        c.close()
        return cs

    # warmup
    cw = connect()
    for _ in range(WARMUP_CALLS):
        cw.request(
            "POST",
            "/charge",
            json.dumps({"seed": 1, "work": work}).encode(),
            {"Content-Type": "application/json"},
        )
        cw.getresponse().read()
    cw.close()

    pers, digs = [], set()
    for _ in range(reps):
        t0 = time.perf_counter_ns()
        cs = once()
        pers.append((time.perf_counter_ns() - t0) / calls)
        digs.add(f"charge:{cs}")
    return {
        "per_call_ns": statistics.median(pers),
        "digest": digs.pop() if len(digs) == 1 else list(digs),
    }


def _governor() -> dict:
    g = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
    t = "/sys/devices/system/cpu/intel_pstate/no_turbo"
    try:
        gov = Path(g).read_text().strip()
        tur = Path(t).read_text().strip() if Path(t).exists() else None
    except OSError:
        gov, tur = None, None
    return {"governor": gov, "turbo_disabled": tur}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", type=int, default=5000)
    ap.add_argument("--calls", type=int, default=200)
    ap.add_argument(
        "--isolated-work",
        type=int,
        default=1,
        help="callee work for the dispatch-isolated pass",
    )
    ap.add_argument("--reps", type=int, default=3)
    ap.add_argument("--rtt-samples", type=int, default=50)
    ap.add_argument(
        "--provider-host",
        default="127.0.0.1",
        help="host of the FastAPI/minimal providers. Loopback (default) = "
        "self-hosted; a non-loopback address = two-box client-only mode "
        "(the provider must already be running there via --serve), giving a "
        "real-network RTT term.",
    )
    ap.add_argument(
        "--provider-port",
        type=int,
        default=0,
        help="fastapi provider port on a remote --provider-host (two-box mode)",
    )
    ap.add_argument(
        "--minimal-port",
        type=int,
        default=0,
        help="minimal_http provider port on a remote --provider-host",
    )
    ap.add_argument(
        "--jac-sv-url",
        default=None,
        help="billing app-server base URL on a remote host (two-box jac_sv). "
        "When set, jac_sv drives rpc_runner against this URL instead of "
        "starting a local billing server.",
    )
    ap.add_argument(
        "--serve",
        choices=["fastapi", "minimal"],
        default=None,
        help="run ONE provider in the foreground (for two-box mode on the "
        "remote machine) and block; requires --port.",
    )
    ap.add_argument("--port", type=int, default=0, help="port for --serve")
    ap.add_argument(
        "--comparands",
        default="direct_inproc,jac_direct,jac_sv,fastapi_httpx,"
        "fastapi_openapi,minimal_http",
    )
    ap.add_argument("--out", required=True, nargs="?")
    args = ap.parse_args()

    # two-box provider mode: launch one server here and block forever.
    if args.serve:
        if not args.port:
            print("ERROR: --serve requires --port", file=sys.stderr)
            sys.exit(2)
        src = FASTAPI_SERVER if args.serve == "fastapi" else MINIMAL_SERVER
        print(
            f"serving {args.serve} on 0.0.0.0:{args.port} (Ctrl-C to stop)",
            file=sys.stderr,
        )
        wd = Path(tempfile.mkdtemp(prefix="xtool_rpc_serve_"))
        script = wd / f"ib_srv_{args.serve}.py"
        script.write_text(src)
        subprocess.run([sys.executable, str(script), str(args.port)])
        return
    if not args.out:
        print("ERROR: --out is required (except with --serve)", file=sys.stderr)
        sys.exit(2)

    want = [c.strip() for c in args.comparands.split(",") if c.strip()]
    gov = _governor()
    if gov["governor"] and gov["governor"] != "performance":
        print(
            f"WARNING: governor '{gov['governor']}' != performance; noisy.",
            file=sys.stderr,
        )

    ref_digest = f"charge:{checksum(args.work, args.calls)}"
    ref_digest_iso = f"charge:{checksum(args.isolated_work, args.calls)}"
    print(
        f"reference matched digest {ref_digest} | isolated {ref_digest_iso}",
        file=sys.stderr,
    )

    workdir = Path(tempfile.mkdtemp(prefix="xtool_rpc_"))
    host = args.provider_host
    results: dict = {}

    def record(name: str, matched: dict, isolated: dict, rtt: dict | None):
        results[name] = {"matched": matched, "isolated": isolated, "rtt": rtt}
        mpc = matched.get("per_call_ns")
        ipc = isolated.get("per_call_ns")
        print(
            f"  {name:16s} matched={_fmt(mpc)} isolated={_fmt(ipc)} "
            f"digest={matched.get('digest')}",
            file=sys.stderr,
        )

    # -- direct_inproc: pure Python, no crossing --
    if "direct_inproc" in want:

        def m() -> float:
            t0 = time.perf_counter_ns()
            checksum(args.work, args.calls)
            return (time.perf_counter_ns() - t0) / args.calls

        def i() -> float:
            t0 = time.perf_counter_ns()
            checksum(args.isolated_work, args.calls)
            return (time.perf_counter_ns() - t0) / args.calls

        record(
            "direct_inproc",
            {"per_call_ns": median_reps(m, args.reps), "digest": ref_digest},
            {"per_call_ns": median_reps(i, args.reps), "digest": ref_digest_iso},
            None,
        )

    # -- jac_direct: in-process Jac baseline --
    if "jac_direct" in want:
        record(
            "jac_direct",
            run_jac_runner("direct_runner.jac", args.work, args.calls, None, args.reps),
            run_jac_runner(
                "direct_runner.jac", args.isolated_work, args.calls, None, args.reps
            ),
            None,
        )

    # -- jac_sv: shipped app-server + sv-import client --
    if "jac_sv" in want:
        res = _jac_sv(args, workdir)
        record("jac_sv", res["matched"], res["isolated"], res["rtt"])

    # -- FastAPI comparands (share one server) --
    fa_lanes = [c for c in ("fastapi_httpx", "fastapi_openapi") if c in want]
    if fa_lanes:
        _run_python_server(
            FASTAPI_SERVER,
            "fastapi",
            args,
            workdir,
            host,
            results,
            record,
            ref_digest,
            ref_digest_iso,
            fa_lanes,
        )

    # -- minimal_http control --
    if "minimal_http" in want:
        _run_minimal(args, workdir, host, record)

    oracle_digests = {
        name: r["matched"].get("digest")
        for name, r in results.items()
        if isinstance(r["matched"].get("digest"), str)
    }
    oracle_ok = len(set(oracle_digests.values())) <= 1 and all(
        d == ref_digest for d in oracle_digests.values()
    )

    shutil.rmtree(workdir, ignore_errors=True)

    doc = {
        "schema_version": 1,
        "kind": "cross_tool_rpc",
        "captured_utc": datetime.now(UTC).isoformat(),
        "work": args.work,
        "calls": args.calls,
        "isolated_work": args.isolated_work,
        "reps": args.reps,
        "provider_host": host,
        "loopback": is_loopback(host),
        "two_box_mode": not is_loopback(host),
        "provider_port": args.provider_port or None,
        "minimal_port": args.minimal_port or None,
        "jac_sv_url": args.jac_sv_url,
        "reference_digest": ref_digest,
        "machine_control": gov,
        "oracle_all_comparands_agree": oracle_ok,
        "note": "matched = per-call at real work; isolated = per-call at "
        "work=1 (framework dispatch + client marshalling). rtt = median "
        "TCP-connect to the provider (the wire term; ~tens of us on "
        "loopback, a real RTT when --provider-host is a second machine)."
        " jac_sv is the shipped path (jac start app server + sv import); "
        "fastapi_* are hand-written/generated-client comparands; "
        "minimal_http is the RPC-physics floor. Digest identity across "
        "all comparands is the oracle.",
        "comparands": results,
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(doc, indent=1))
    print(f"wrote {out} (oracle_ok={oracle_ok})", file=sys.stderr)
    if not oracle_ok:
        print("ORACLE FAILED: comparands disagree on the checksum.", file=sys.stderr)
        sys.exit(3)


def _fmt(x: object) -> str:
    return f"{x:10.1f}ns" if isinstance(x, (int, float)) else f"{x}"


def _jac_sv(args: argparse.Namespace, workdir: Path) -> dict:
    """Start jac billing provider, drive rpc_runner for matched + isolated."""
    jac = shutil.which("jac")
    if jac is None:
        return {
            "matched": {"skipped": "jac not on PATH"},
            "isolated": {"skipped": "jac not on PATH"},
            "rtt": None,
        }
    # two-box: bill against a remote billing server, don't launch locally.
    if args.jac_sv_url:
        from urllib.parse import urlparse

        u = urlparse(args.jac_sv_url)
        rtt = tcp_rtt_ns(u.hostname, u.port or 80, args.rtt_samples)
        env = {"JAC_SV_BILLING_URL": args.jac_sv_url}
        return {
            "matched": run_jac_runner(
                "rpc_runner.jac", args.work, args.calls, env, args.reps
            ),
            "isolated": run_jac_runner(
                "rpc_runner.jac", args.isolated_work, args.calls, env, args.reps
            ),
            "rtt": rtt,
        }
    port = free_port()
    log = workdir / "jac_sv.log"
    logf = log.open("w")
    proc = subprocess.Popen(
        [jac, "start", "billing.jac", "--port", str(port)],
        cwd=str(SVC),
        stdout=logf,
        stderr=subprocess.STDOUT,
    )
    try:
        wait_ready(lambda: http_ok("127.0.0.1", port, "/healthz"), 60, log)
        rtt = tcp_rtt_ns("127.0.0.1", port, args.rtt_samples)
        env = {"JAC_SV_BILLING_URL": f"http://127.0.0.1:{port}"}
        matched = run_jac_runner(
            "rpc_runner.jac", args.work, args.calls, env, args.reps
        )
        isolated = run_jac_runner(
            "rpc_runner.jac", args.isolated_work, args.calls, env, args.reps
        )
        return {"matched": matched, "isolated": isolated, "rtt": rtt}
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        logf.close()


def _run_python_server(
    source: str,
    name: str,
    args: argparse.Namespace,
    workdir: Path,
    host: str,
    results: dict,
    record: Callable[..., None],
    ref_digest: str,
    ref_digest_iso: str,
    lanes: list[str],
) -> None:
    remote = not is_loopback(host)
    if remote and not args.provider_port:
        print(
            "ERROR: --provider-host is remote but --provider-port not set; "
            "skipping fastapi lanes.",
            file=sys.stderr,
        )
        return

    def _drive(port: int) -> None:
        rtt = tcp_rtt_ns(host, port, args.rtt_samples)
        path = "/function/charge_card"

        def unwrap(j: dict) -> int:
            return j["data"]["result"]

        if "fastapi_httpx" in lanes:
            record(
                "fastapi_httpx",
                client_httpx(
                    host, port, path, args.work, args.calls, unwrap, args.reps
                ),
                client_httpx(
                    host, port, path, args.isolated_work, args.calls, unwrap, args.reps
                ),
                rtt,
            )
        if "fastapi_openapi" in lanes:
            record(
                "fastapi_openapi",
                client_openapi_equiv(
                    host, port, path, args.work, args.calls, args.reps
                ),
                client_openapi_equiv(
                    host, port, path, args.isolated_work, args.calls, args.reps
                ),
                rtt,
            )

    if remote:
        # two-box: provider already running on the remote; connect, don't launch.
        wait_ready(lambda: http_ok(host, args.provider_port, "/healthz"), 30)
        _drive(args.provider_port)
    else:
        port = free_port()
        with Server(source, port, workdir, name):
            _drive(port)


def _run_minimal(
    args: argparse.Namespace,
    workdir: Path,
    host: str,
    record: Callable[..., None],
) -> None:
    def _drive(port: int) -> None:
        rtt = tcp_rtt_ns(host, port, args.rtt_samples)
        record(
            "minimal_http",
            client_minimal(host, port, args.work, args.calls, args.reps),
            client_minimal(host, port, args.isolated_work, args.calls, args.reps),
            rtt,
        )

    if not is_loopback(host):
        if not args.minimal_port:
            print(
                "ERROR: remote --provider-host but --minimal-port not set; "
                "skipping minimal_http.",
                file=sys.stderr,
            )
            return
        wait_ready(lambda: http_ok(host, args.minimal_port, "/healthz"), 30)
        _drive(args.minimal_port)
    else:
        port = free_port()
        with Server(MINIMAL_SERVER, port, workdir, "minimal"):
            _drive(port)


if __name__ == "__main__":
    main()
