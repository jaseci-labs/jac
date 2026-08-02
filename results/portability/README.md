# Portability re-capture: do the ratios port across machines?

The paper's claim is that the **ratios** are portable while the **absolute
nanoseconds** are clock/uarch-specific. This directory holds per-machine
re-captures to test that. Each subdir is one machine, produced by
`scripts/portability_recapture.sh <label>`.

## How to add a second machine

On a different box (ideally arm64), with a working `jac` + `node` and the CPU
governor pinned to `performance`:

```sh
scripts/portability_recapture.sh <label>     # e.g. arm64-m2
```

It captures env provenance + the family-1 work sweep + the payload sweep +
cross-runtime small, then prints the ratios. Compare its printed ratios (and the
table below) against `ultra7-255h`.

## Reference: `ultra7-255h` (Intel Core Ultra 7 255H, x86_64, performance + no-turbo)

Independent re-capture via the portability harness; reproduces the canonical
`results/controlled/` dataset.

| ratio (portable) | ultra7-255h | canonical | absolutes (machine-specific) |
|---|---|---|---|
| placement sv/na slope | **41.9x** | ~42x | sv 215, na 5.1 ns/it |
| payload rpc/direct slope | **2.77x** | ~2.6x | direct 341, rpc 945 ns/el |
| xop_svc_split rpc/direct | 331x | 369x (CV 3.7%) | direct ~805us |
| xop_feed client/direct | 255x | 243x (CV 3.0%) | direct ~805us |
| xop_wasm_call wasm/native | **6.8x** | 6.8x | native ~19us |

The RATIOS should reproduce within a few percent on any machine; the absolute
ns will move with clock and microarchitecture. Divergence in a ratio (not an
absolute) is the interesting signal.
