# Cross-tool verdict matrix + real-network RTT (2026-07-25)

Delivers the three scope expansions the paper's Related Work / Conclusion
deferred: (1) the **FastAPI/RPC verdict matrix**, (2) a **real-network RTT**
decomposition, and (3) **more kernels** for the cross-tool FFI comparison.
Prior to this the tab:xtool numbers had **no committed producer** (STEPS.md #39);
both axes are now reproducible from one source of truth each.

Pinned governor (`performance`) + turbo off, same machine as the canonical
dataset. Python-side comparands run in a `--system-site-packages` venv
(`scripts/.xtool-venv`, gitignored) carrying `fastapi`, `pybind11`, `httpx`.

## Producers

| script | dataset | oracle |
|---|---|---|
| `scripts/xtool_ffi.py` | `xtool_ffi_noturbo.json` | one byte-identical digest per kernel across ctypes/cffi/cext/pybind11/pyo3 |
| `scripts/xtool_rpc.py` | `xtool_rpc_noturbo.json` | one `charge:<checksum>` across all six RPC comparands |

Both ABORT if any toolchain/comparand disagrees. Both passed
(`oracle_all_*_agree: true`).

## 1 + 3. Cross-tool FFI, three kernels (STEPS #39, "more kernels")

Same C fixture bound five ways; **isolated** per-call boundary (tight call loop
minus empty loop), ns:

| kernel | ctypes | cffi | cext | pybind11 | pyo3 | Jac na |
|---|---|---|---|---|---|---|
| `sqrt` (scalar) | 361 | 184 | 23 | 48 | 61 | **3** |
| `struct` (Vec3 by-value) | 1131 | 1103 | 87 | 116 | 134 | -- |
| `bytes` (16B FNV-1a) | 590 | 374 | 65 | 145 | 101 | -- |

**New finding the single `sqrt` kernel could not show:** struct-by-value
marshalling costs `ctypes`/`cffi` **~1.1 us** -- the byval-copy tax the paper's
register-vs-byval point predicts -- while the compiled bindings (`cext`,
`pybind11`, `pyo3`) stay in a ~90-135 ns band. The cross-tool "mechanism band"
is therefore signature-dependent, not a single number: tight (23-61 ns) for a
scalar, an order of magnitude wider for a struct. `cext` is the floor on every
kernel; the descriptor-driven tools (`ctypes`, `cffi`) pay the most and pay it
most on the struct. Jac-native FFI anchors at 3 ns/call (the existing
`iop_ffi_scalar` kernel).

## 2. RPC verdict matrix + RTT

Same `charge_card` checksum, `work=5000`, `calls=200`, 3 reps. **matched** =
per-call at real work; **isolated** = per-call at `work=1` (boundary =
framework dispatch + client marshalling); **rtt** = median TCP-connect.

| comparand | matched | isolated (boundary) | vs jac_sv boundary |
|---|---|---|---|
| `direct_inproc` (no crossing) | 1.01 ms | ~0 | -- |
| `jac_direct` (Jac in-proc) | 1.04 ms | ~0 | -- |
| `minimal_http` (bare endpoint, control) | 2.02 ms | **0.61 ms** | 25.5x cheaper |
| `fastapi_httpx` (hand-written glue) | 3.25 ms | **1.60 ms** | 9.7x cheaper |
| `fastapi_openapi` (generated-client-equiv) | 3.12 ms | 1.51 ms | ~10x cheaper |
| `jac_sv` (**shipped** app-server + sv-import) | 16.09 ms | **15.49 ms** | -- |

**The verdict (this is the contribution the paper deferred):** Jac's shipped
generated RPC crossing is **~10x** a hand-written FastAPI+httpx client and
**~25x** a minimal endpoint on the pure-boundary term -- the same
"compiler-generated crossing costs more than hand-rolled glue" shape the FFI
table shows, now measured on the RPC axis. The generated-OpenAPI-equivalent
client (pydantic request/response validation over httpx) adds no measurable cost
over hand httpx here (~1.5 vs 1.6 ms), so the gap is the Jac app-server stack +
sv-import runtime, not client-side typing.

**RTT decomposition (real-network capability):** loopback TCP-connect is **~30
us** -- i.e. the 15.5 ms `jac_sv` boundary is ~500x the wire term, confirming
directly (across the whole comparand matrix, not just one probe) that the floor
is framework + marshalling, **not** network. `scripts/xtool_rpc.py
--provider-host <second-machine>` measures a genuine RTT term against a remote
provider; the wire term is always reported separately so marshalling and network
are never conflated. The cross-machine campaign itself remains future work; the
instrument and the loopback baseline are delivered here.

## Scope of claims

Isolated-boundary ns and the RPC boundary ratios are the portable results;
absolutes are specific to this CPU (Ultra 7 255H, pinned base clock). The
`fastapi_*` and `minimal_http` numbers are honest **hand-written comparands**,
not a claim that a maximally-tuned RPC stack could not go lower -- they bound
the verdict from the side a normal developer would actually reach for.
