# results/paper-canonical/

The ONE artifact set the paper is built from (STEPS.md Phase A, item 5;
interop-bench#3). Produced by a single committed pipeline:

```sh
scripts/run_canonical.sh          # full canonical run (requires a pinned clock)
python3 scripts/audit.py          # verify the bundle's invariants
```

`run_canonical.sh` refuses to run unless the git worktree is clean and the CPU
governor is pinned to `performance`, so the bundle always corresponds to one
frozen revision recorded in `MANIFEST.json`.

## Layout

- `env.json` -- frozen revision + environment manifest
  (`scripts/capture_env.py`). Build gate: `git_dirty` must be `false`.
- `aggregate/` -- the four producer outputs:
  - `xtool_ffi.json` -- cross-tool FFI (one C translation unit bound five ways;
    matched signatures incl. struct-by-value; oracle-gated).
  - `sweep.json` -- controlled multi-work sweep (every cell has exactly `reps`
    samples or the run aborts).
  - `payload.json` -- payload-cardinality sweep (>=3 reps aggregated).
  - `xtool_rpc.json` -- cross-tool RPC verdict matrix + RTT.
- `logs/` -- full stdout/stderr of every producing run.
- `MANIFEST.json` -- git sha + sha256 of every file above.

**Raw per-invocation samples are never discarded** (item 6; interop-bench#7):
they are embedded inside each aggregate JSON -- `samples` (sweep),
`raw_per_call_ns` / `raw_samples_ns` (payload), `samples` (FFI/RPC reps) -- so
every reported median and its bootstrap CI is reconstructible from this bundle
alone. `scripts/audit.py` verifies exactly that.

Acceptance criterion (item 5): a reviewer can verify that every table value in
`paper.tex` was produced by a script from these files, not copied by hand.
