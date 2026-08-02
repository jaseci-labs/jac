# Oracle-efficacy seeded-fault study (2026-07-25)

Evaluates the differential-identity oracle (byte-identical twin digests, CI-gated)
by injecting seeded faults into the crossing side of the kernels and measuring the
catch rate. Ran in an isolated worktree; tree reverted between mutations.

## Method

21 mutations across 7 twin groups (iop_call, iop_cb, iop_symmetric,
iop_ffi_struct, iop_ffi_vtable, xop_feed_payload, xop_svc_split), each modeling a
target bug class. Applied in isolation; oracle group re-run at the CI operating
point (small = work 200 / calls 20; payload N=50); digests compared exactly as
`common.jac:compare_oracle`; structural audit (`harness/audit.jac`) run where
applicable; reverted before the next.

## Headline

- **Result-corrupting mutations observable at CI size: 14/14 caught (100%).**
- **False positives on 3 timing-only mutations: 0** (oracle is orthogonal to
  timing -- why frequency pinning is a separate, necessary control).
- **All 17 non-timing seeded faults: 14 by oracle, 15 with audit (82% / 88%).**
- One type-confusion fault (`return "oops"` from an int-typed export) was caught
  by the oracle after the type checker ACCEPTED it.

## Escapes (each a real scope limit, not a flaw)

- **M12 common-mode**: provider LCG bug in source shared by both twins -> both
  digests move identically -> structurally invisible to any differential oracle.
- **M17 input-domain-masked narrowing**: vec12 sum cast to int16; truncation only
  observable at N>=10,922, beyond CI (200) and default (5000) sizes. Catch power
  is input-domain-dependent.
- **M18 pass-through ABI declaration skew**: struct field i32->i64 decl mismatch
  on a C-make -> C-sum pass-through path; skewed bytes never observed -> evades
  oracle AND structural audit. Latent hazard.

## Oracle vs audit division of labor

- **M03b boundary erasure**: reference side silently promoted to native; digests
  stay byte-identical while per-call cost collapses 41.2us -> 4.7us. Caught ONLY
  by the audit's export-manifest gate, not the oracle.
- Conversely M19 (type confusion) caught by the oracle after slipping past the
  type checker.

## Full mutation table

| # | Site | Mutation | Class | Oracle | Audit |
|---|------|----------|-------|--------|-------|
| M01 | iop_call na{} | LCG increment 12345->12346 | codegen drift | CAUGHT | n/a |
| M02 | iop_call na{} | modulus 2^31->2^31-1 | overflow drift | CAUGHT | n/a |
| M03b | iop_call | reference side pinned na{} | boundary erasure | MISSED | CAUGHT (audit) |
| M04 | iop_call na{} | dead LCG loop, discarded | timing-only | TN | n/a |
| M05 | iop_cb na{} | callback args swapped | arg marshalling | CAUGHT | n/a |
| M06 | iop_cb na{} | callback result %65536 | truncation | CAUGHT | n/a |
| M07 | iop_symmetric na{} | multiplier +1 | codegen drift | CAUGHT | n/a |
| M08 | iop_symmetric na{} | dead loop | timing-only | TN | n/a |
| M09 | rpc_runner | drop first payload element | dropped element | CAUGHT | n/a |
| M10 | rpc_runner | duplicate first element | dup element | CAUGHT | n/a |
| M11 | rpc_runner | seed off-by-one | arg corruption | CAUGHT | n/a |
| M12 | feedbatch (provider) | LCG increment +1 (shared src) | common-mode | MISSED | n/a |
| M13 | rpc_runner | 20k busy loop/call | timing-only | TN | n/a |
| M14 | svc_split rpc_runner | consumer modulus change | overflow drift | CAUGHT | n/a |
| M15 | interopbench.c | vec24_sum drops field c | field truncation | CAUGHT | markers unchanged |
| M16 | interopbench.c | vec44 modulus 1009->1013 | value drift | CAUGHT | markers unchanged |
| M17 | interopbench.c | vec12_sum cast int16 | narrowing | MISSED at CI | blind |
| M18 | iop_ffi_struct | field i32->i64 decl skew | ABI decl skew | MISSED | blind |
| M19 | iop_call na{} | return "oops" from int export | type confusion | CAUGHT | n/a |
| M20 | interopbench.c | vec4_sum byte-swap | byte order | CAUGHT | n/a |
| M21 | interopbench.c | trampoline on_event(b,a) | callback arg order | CAUGHT | n/a |

Baselines: call/callback/symmetric/charge=263997602, struct=21396320,
vtable=4036000, payload=2122560274.
