# Language server performance

Run from the repository root with a Jac executable that includes
`jaclang.testing.lsp_client`:

```sh
jac run scripts/lsp_bench.jac --scenario medium --rounds 5 --output /tmp/lsp-results
jac run scripts/lsp_bench.jac --scenario annex --rounds 5 --output /tmp/lsp-results
jac run scripts/lsp_bench.jac --scenario workspace --documents 20 --rounds 3 --output /tmp/lsp-results
jac run scripts/lsp_bench.jac --scenario soak --iterations 100 --output /tmp/lsp-results
```

`small`, `medium`, and `large` generate 10, 250, and 1,250 functions. They measure
opening, the first and subsequent semantic queries, edit-to-diagnostics latency,
completion and hover queued immediately after an edit, a ten-edit burst, and
cancellation. `annex` moves the 250 function bodies into an implementation annex,
edits that annex, and queries the declaration file. `workspace` changes a closed dependency and verifies diagnostics
in every open consumer through repeated break/fix cycles. `soak` opens, edits,
and closes different modules with different imports, retaining a memory sample
after every completed close.

All timings include JSON-RPC transport; diagnostic timings include debounce.
The JSON records every sample, median, nearest-rank p95, and maximum. Startup
and first-query costs are separate from steady state. RSS and peak RSS are the
server process's Linux `VmRSS` and `VmHWM`, not the benchmark's memory or a sum
over child processes. Other platforms report unavailable memory as `null`.

To compare built binaries, run the same script and workload twice:

```sh
jac run scripts/lsp_bench.jac --scenario medium --server /path/to/base/jac --sealed-server --output /tmp/lsp-base
jac run scripts/lsp_bench.jac --scenario medium --server /path/to/candidate/jac --sealed-server --output /tmp/lsp-candidate
```

`--sealed-server` disables the checkout's compiler override in the child server.
Without it, a development checkout can cause both commands to run the same
compiler source. Single-file measurements also accept unversioned diagnostics
from older servers, while checking that each notification arrived after the
edit. Workspace and soak scenarios require the current document lifecycle and
file-watching behavior.

Keep the machine, compiler kernel, cache policy, workload, and number of rounds
the same. A cold development compiler may compile itself inside the first
session; compare sealed binaries when measuring production startup and memory.
Run enough rounds to assess variation and preserve the raw results.

`--budgets /path/to/budgets.json` accepts operation names mapped to the existing
CI `Budget` format, for example:

```json
{"edit-completion": {"wall_seconds": 4, "max_rss_mib": 1024}}
```

The script uses `scripts/ci_perf.jac` to check p95 wall time and peak server RSS.
Missing requested measurements and unavailable requested memory accounting
fail the gate. The soak operation is named `soak-cycle`.
