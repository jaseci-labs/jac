# results/

All interopbench result artifacts. Nothing here is hand-edited; every file is
produced by a committed script in `../scripts/`.

Layout (per STEPS.md Phase A, items 2 & 5):

```
results/
  archive/          # quarantined historical captures (NEVER silently deleted)
    <YYYY-MM-DD>-<n<N>>/   # one dir per past capture, with a MANIFEST.json
  paper-canonical/  # the single canonical artifact set the paper is built from
    env.json        # output of `python ../scripts/capture_env.py`
    raw/            # per-invocation timings (item 6: store raw, not only medians)
    aggregate/      # aggregated JSON + plots data
    logs/           # captured stdout/stderr per run
```

## Quaranantine rules (item 2)

Every entry under `archive/` MUST contain a `MANIFEST.json` (see
`archive/MANIFEST.template.json`) recording:

- capture timestamp
- git SHA (+ whether the worktree was clean)
- exact invocation command
- environment summary (toolchain + machine)
- sample count
- whether the machine state was controlled
- known code changes since the previous capture
- why this capture is or is NOT suitable for publication

**Do not delete contradictory results.** Reviewers will read deletion of an
unfavourable 30-sample capture as cherry-picking. Archive it with its reason.
