# T7 -- known-na-cliffs conformance gate

The na-clean object core (`Objects/`) is validated against Jac's native backend
**from day one**, so the dual-substrate bet (PLAN.md §4, D4) is continuously
tested rather than discovered broken at P7. This directory is the seed.

Each cliff isolates one documented na landmine **as jacpython's core already
uses it** -- these are not abstract; they are the exact shapes in the marshal
reader, `exec_module`, `deref_cell`, and `bytes_to_str`.

## The cliffs

| Fixture | na landmine | jac-py core site | Memory |
|---|---|---|---|
| `cliff_list_int_subscript.na.jac` | `list[int]` subscript | `Reader.r_byte`: `self.data[self.pos]` | na-container-capabilities-2026-07 |
| `cliff_dict_return.na.jac` | dict build/return/subscript (ICE?) | `exec_module() -> dict[str, PyObj]`, `PyDict.items` | na-container-capabilities-2026-07 |
| `cliff_union_receiver.na.jac` | field on `T\|None` receiver (silent drop) | `deref_cell/find_cell/find_handler -> …\|None` then `.val`/`.target` | na-method-call-on-union-receiver |
| `cliff_binary_buffer.na.jac` | str concat drops NUL, `len`=strlen | `bytes_to_str` builds str from bytes incl NUL | na-chr-concat-drops-nul, na-len-strlen-binary-guard |
| `cliff_user_dispatch.na.jac` | data-driven `dict[str,PyObj]` method dispatch over an MRO, no fn values (dynamism) | `PyUserObj.tp_getattro` instance-dict-wins-then-`class_mro`-walk + vtable invoke | na-dict-literal-subclass-upcast-ice, na-method-call-on-union-receiver |
| `cliff_gen_frame.na.jac` | generator as suspended-frame state machine: resume-into-try/finally, expr-position yield, yield-from (dynamism) | `PyFrame`/`PyGenerator` suspend/resume machinery | na-lexical-exceptions-finally-lift |
| `cliff_op_switch.na.jac` | large N-way (40-arm) method-id switch at the dict-value-to-native-call boundary (dynamism scale) | `nb_binop` operator-slot dispatch table | native-no-indirect-calls |
| `cliff_descriptor.na.jac` | attribute protocol: data-descriptor `__get__` preempts instance dict, `__getattr__` on miss (dynamism) | `PyUserObj.tp_getattro` descriptor + `__getattr__` chain | na-dict-literal-subclass-upcast-ice |
| `cliff_reflected_op.na.jac` | reflected binop: `__radd__` fallback on NotImplemented over the MRO (dynamism) | `nb_binop` reflected-slot dispatch over `PyUserObj` operands | na-method-call-on-union-receiver |
| `cliff_except_match.na.jac` | except-arm matching by MRO walk, first-match-wins (dynamism) | `exception_matches`/`CHECK_EXC_MATCH` + `class_mro` | na-lexical-exceptions-finally-lift |

## Two gates

**Local (compile gate).** `jac nacompile <cliff>.na.jac` must reach
`Object code emitted` with **no `E5090`** and no compiler ICE. Runs without the
LLVM shim -- capability check + IR-gen + object emit all happen before the
musl-link step. Drive with `python t7_gate.py`.

**CI (runtime gate).** Link the emitted object (vendored musl, or system `cc`
per commit f9a89e079) and run it; diff the result against the bytecode-backend
truth pinned in `na_cliffs_ref.jac`. This is what catches the *runtime*
miscompiles (NUL-drop → `len` returns 1 not 2; union-receiver-drop → wrong
value) that compile cleanly but compute the wrong answer.

## Measured status (local, 2026-07-15)

All ten **pass the compile gate**: capability-clean, LLVM IR generated, object
code emitted (6.4–66 KB). Only the final static-musl link is blocked locally
(environment, not code -- no vendored musl on this box). Runtime-correctness legs
are therefore **pending CI** (or a local musl / system-`cc` link). Notably the
dict-return shape did **not** ICE here -- better than the folklore; the ratchet
records the measured truth per CPython/jaclang bump.

**The leaf itself compiles.** `t7_gate.py` also nacompiles the whole na-clean
object core (`jacpython/objects.jac`) self-contained: all 18 data types + slots

+ the `isinstance`-based helpers generate LLVM IR and emit **122 KB of object
code** with zero E5090 (musl link env-blocked, as above). So the leaf is na-clean
in fact, not just by inspection.

**Dynamism proven, not just de-risked (2026-07-18).** The two risk rows the
reviewer flagged -- na no-indirect-calls vs Python's inherent dynamism -- now have
*demonstrated* cliffs, not paper arguments. `cliff_user_dispatch` compiles a
faithful `PyUserObj.tp_getattro` shape (runtime-computed keys, ≥2 classes binding
the same method name to different behavior, a heterogeneous instance list, a
3-level MRO walk with mid-chain override, and a runtime attrs-dict mutation +
same-call-site re-dispatch -- all uncheatable against devirtualization) with **0
E5090**, and its bytecode-backend truth (`na_cliffs_ref.jac` cliff 5) pins
`136 / 1005 / 1141`. `cliff_gen_frame` compiles a generator-as-suspended-frame
state machine (integer `ip` over data, no fn values) covering the genuinely hard
cases a naive machine dodges -- resuming into an active `try/finally` that
`close()` must run (finally lifted to an ip-state on every exit path, idempotent
double-close), expression-position yield with value-stack spill, and yield-from
delegation -- with cliff-6 truth `310610 / 3150101`. Two real na-codegen findings
fell out and are worked around in-fixture (never in the leaf): the **dict-literal
subclass-upcast ICE** (build empty + subscript-store) and na's **lexically-
structured exceptions** (no mid-`try` resume). Runtime legs verified on the
bytecode backend now; the na-linked legs remain **unwired** (no CI leg exists
yet -- they need a musl/system-cc link environment; see "Two gates" above).

**Dynamism surface widened (2026-07-18, cliffs 7--10).** Four more shapes the
port depends on now compile na-clean with bytecode-backend truth pinned: (7)
`cliff_op_switch` -- a **40-arm** runtime-keyed method-id switch at the
dict-value-to-native-call boundary (the advisor's #1 suspected *scale* cliff);
it does **not** reproduce, na resolves all 40 arms statically (truth `163283`).
(8) `cliff_descriptor` -- the full attribute-precedence chain: a data-descriptor
`__get__` preempting a present instance-dict entry, `__getattr__` only on total
miss, and a mutation flipping two opposite precedence rulings at one site (truth
`1125777105`). (9) `cliff_reflected_op` -- reflected-binop fallback: forward
`__add__` returns NotImplemented, only `type(b).__radd__` (reached by a real MRO
walk) supplies the answer; ordering and both-decline-to-TypeError asserted (truth
`3038`). (10) `cliff_except_match` -- `except`-arm selection by MRO walk with
first-match-wins (base-match not exact, broad-before-specific shadowing), handler
selection lifted to integer data per the lexical-exception constraint (truth
`20100130`). No new na findings in any of the four; the closed method-id switch,
descriptor protocol, reflected dispatch, and exception matching are all na-clean.

**Known na multi-module gap.** Compiling `objects.jac` via a separate entry that
`import from objects { … }` fails with E5090 on the *imported* symbols -- na's
multi-module native resolution (see memory `na-resolver-import-order-priming`,
`na-shared-multimodule-rc-wrapper`), not a leaf defect. The eventual
`jacpython.na.jac` native entry will need the flat-module-set priming or the
`--shared` path; tracked for P7.
