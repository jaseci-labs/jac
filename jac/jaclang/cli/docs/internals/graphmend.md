# GraphMend: FX Graph-Break Elimination

GraphMend is an opt-in set of compiler passes (`jac run --graphmend` / `-g`)
that rewrites PyTorch 2 code so `torch.compile` captures one contiguous FX
graph instead of a fragmented one. TorchDynamo falls back to eager execution
(a "graph break") whenever traced code forces a Python-level decision on
tensor data: a data-dependent `if`, a validation guard that raises, or an
untraceable side-effect call. Each break splits the compiled region and costs
real latency. GraphMend detects the fixable break patterns in the unified IR
(AST, CFG and symbol table together) and re-expresses them as graph-native
dataflow, before Python code generation, so only the Python lowering target is
affected. The JS and native backends see the original tree.

This page is the specification and legality argument for the passes that have
landed. It currently covers detection, trap lowering and predication
(`torch.where` / `torch.cond`); the side-effect deferral transform extends
this page when it lands.

## Activation and plumbing

- `jac run -g model.py` (or `model.jac`) sets `graphmend_enabled` on the
  active `JacProgram`.
- `JacCompiler.get_bytecode` translates that into
  `CompileOptions(graphmend=True)` for user modules. Internal `jaclang.*`
  modules are exempt: they contain no `torch.compile` entry points, so their
  bytecode is flag-independent and recompiling them per run would be waste.
- Every GraphMend pass gates itself on `CompileOptions.graphmend` in
  `before_pass` and prunes immediately when the flag is off, so the schedule
  is inert for normal compiles.
- The passes run in `get_py_code_gen`, immediately before `PyastGenPass`:
  `GraphBreakDetectPass`, then `TrapLoweringPass`, then
  `PredicateCtrlFlowPass`. The order is load-bearing: trap lowering removes
  the `raise` from a validation guard nested inside a data-dependent branch,
  which is what lets predication later hoist that branch's setup statements
  (the lowered assert is re-gated on the branch predicate, see below).
- Cross-pass state is typed and lives on `JacProgram`, not on AST nodes:
  `graphmend_breaks` maps a node id to its `GraphBreakKind` (detection to
  transformation), and `graphmend_helpers` maps a module id to the set of
  `GraphMendHelper` values whose imports the preamble must emit
  (transformation to code generation). Keying analysis results by node id on
  the program is the same idiom `_analyses_run` uses.
- Caching: transformed bytecode must never be served to (or from) a normal
  run. While GraphMend is active the compiler skips the sealed-JIR fast path,
  the on-disk module cache and the precompiled-JIR bundle, and does not write
  the compile result back to the cache. The in-memory hub is safe because the
  flag is constant within a single process. (Variant-keyed cache slots, which
  restore caching under the flag, arrive with the scoped-import work.)

## Detection: `GraphBreakDetectPass`

Detection implements the paper's Dynamo entry-point analysis plus graph-break
type analysis. It records a `GraphBreakKind` (declared in
`jac0core/constant.jac`) per break site; each kind names the single transform
allowed to lower it. Detection breadth grows in lockstep with the transforms:
a data-dependent conditional whose body is exactly one `raise` is tagged
`VAL_GUARD` (consumed by `TrapLoweringPass`); any other data-dependent
conditional is tagged `DYN_CTRL_FL` (consumed by `PredicateCtrlFlowPass`);
a `print` or logger-style call inside a compiled region is tagged
`SIDE_EFFECT` (consumed by `DeferSideEffectPass`). Side-effect names are
matched by `is_side_effect_name` in `torch_attr_table.jac`: the bare builtin
`print`, plus any callee whose name contains a logging keyword. A name that
resolves to a user-defined symbol is skipped, so a local function that
happens to be called `print_stats` is never rewritten.

### Entry points

A function or class is in scope when it is `@torch.compile`-decorated
(matched via `has_torch_compile_decorator` in `torch_attr_table.jac`) or
wrapped at a call site: `torch.compile(fn)`, `torch.compile(Model())`, and
`m = Model(); torch.compile(m)` all resolve through the symbol table to the
defining function or class, whose methods then count as in scope. A module
imported under `--graphmend-scope` is treated as one whole compiled region
(no local entry point required). Everything outside an entry point is left
untouched.

Decorators are matched structurally (a `torch` name with a trailing `compile`
attribute), never by unparsing to text: Python-origin (`.py`) and Jac-origin
(`.jac`) trees unparse differently, so a text match silently fails on `.py`
models, which are the primary target (`jac run model.py -g`).

### Data dependence

A condition is data-dependent when it uses a dynamic torch attribute
directly, or when a bounded use-def trace shows it derives from one. The
dynamic-attribute table (`graphmend/torch_attr_table.jac`) lists ops whose
result depends on tensor data rather than static shape: `item`, `tolist`,
reductions, `nonzero`, `equal`, `allclose`, `unique` and so on. Extending
detection to a new op is one entry in that table. The use-def trace follows
each name in the condition back through its defining assignment (depth-capped
and cycle-guarded), so `seq_len = torch.max(position_ids) + 1` makes a later
`if seq_len > limit:` data-dependent even though the condition itself names
no torch op. Guard shapes the trap transform accepts always name their
dynamic op inline; branch conditions genuinely need the trace, which is why
it landed with the predication pass.

One deliberate precision choice: function parameters are NOT assumed dynamic.
Treating every parameter as tensor-derived would tag static guards such as
`if not isinstance(flag, str): raise`, which Dynamo handles without a break,
and rewriting them would be wrong. Detection keys on torch dynamic
attributes.

## Trap lowering: `TrapLoweringPass`

Validation guards of the form

```python
if not torch.equal(a, b):
    raise ValueError("unsupported attention mask")
```

raise on a data-dependent boolean, which forces the tensor back into the
interpreter and breaks the graph. Unlike data-dependent control flow they
produce no tensor output, so a `torch.where` mux does not apply. Instead the
guard is lowered to a graph-native assertion that raises at runtime without
breaking the graph:

```python
__jac_tensor_eq_assert__(a, b, '[[GM-TRAP ValueError]]unsupported attention mask[[/GM-TRAP]]')
```

and for a condition that is already a tensor boolean
(`.all()` / `.any()` / `.allclose()`):

```python
torch._assert_async(mask.all(), '[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')
```

### Legality conditions

The pass is a conservative must-analysis: it fires only when safety is
established, and absence of proof means the guard is left intact. A break
left unfixed is a soundness property, not a defect.

1. The tagged `IfStmt` body is exactly one `raise` statement, and the
   condition is a unary `not X`. Only then is "assert X must hold" the exact
   meaning of the original guard.
2. `X` must be convertible to a tensor boolean. Two cases are accepted:
   `torch.equal(a, b)` (returns a Python bool, special-cased below) and calls
   already returning a tensor bool (`.all`, `.any`, `.allclose`). Anything
   else declines.
3. `torch.equal` is rebuilt by the runtime helper `tensor_eq_assert` as a
   tensor op with a static precheck: shapes and dtypes must match before
   evaluating `(a == b).all()`, else the assert condition is a constant
   `tensor(False)`. The precheck is what keeps the rewrite value-equivalent:
   without it, broadcasting could make `(a == b).all()` true for shapes that
   `torch.equal` reports as unequal, and the precheck itself is static
   metadata that adds no break.
4. The original exception must be reconstructible at the call boundary, or the
   guard is left intact. This needs three things at once: an enclosing
   `@torch.compile`-decorated ability to carry the eager decorator, a named
   exception type, and a message that is a pure string literal. Three shapes
   therefore decline. An f-string declines because a `MultiString` contributes
   only its `String` parts to a literal value, so folding one would produce a
   marker wrapped around an empty message -- the right exception type with its
   diagnostic silently dropped. A runtime expression (concatenation,
   `%`-formatting) declines because no marker can be built at all, which would
   surface the failure as `RuntimeError` instead of the original type. A guard
   inside a `@torch.compile`-decorated *class* declines for want of a boundary:
   the method carries no decorator of its own, and an async assert can surface
   after that method has already returned. Detection still tags all three --
   the decline belongs to the transform, not to the analysis.

### Exception-type preservation

`torch._assert_async` raises `RuntimeError`, and a graph-native assertion
fails asynchronously: the error surfaces at the call boundary, outside the
traced region, where an in-source `try`/`except` cannot catch it. When the
guard sits in a `@torch.compile`-decorated function and the message is a
string literal, the pass folds a self-describing marker into the message
literal at compile time (`[[GM-TRAP ValueError]]msg[[/GM-TRAP]]`) and
prepends the eager boundary decorator `@__jac_trap_guard__` to the function.
The decorator catches the `RuntimeError` at the boundary, parses the marker,
and re-raises the original exception type with the original message; unmarked
`RuntimeError`s propagate unchanged, and unknown (non-builtin) types degrade
to `RuntimeError` so no message is ever lost.

The marker is folded at compile time, not concatenated at runtime, so the
assert stays a native torch op inside the graph. That also makes the marker
the limit of what can be preserved: a runtime concat to rebuild a dynamic
message would reintroduce the break it is trying to remove, so there is no
fallback. When the marker cannot be built -- a non-literal message, or an
entry point compiled at a call site with nothing to decorate -- the pass
declines under condition 4 rather than lowering a guard whose exception
contract it cannot honor. Widening this is a coverage question for later
passes (call-site entry resolution lands with the scoped-import PR), not a
licence to weaken the contract now.

### Runtime support

Two helpers back the transform, exported through `jaclib` and imported by the
generated module preamble only when the pass actually used them
(`__jac_tensor_eq_assert__`, `__jac_trap_guard__`). Both live on `JacBuiltin`
in `jac0core/runtime.jac`.

## Predication: `PredicateCtrlFlowPass`

A data-dependent `if`/`else` (tagged `DYN_CTRL_FL`) forces TorchDynamo to
pick a Python path from tensor data, splitting the graph at the branch. The
pass rewrites the branch into a single graph-native selection so both paths
stay inside one FX graph. It fires only when both branches produce the same
output, so the rewrite is provably semantics-preserving; anything more
complex (differing targets, elif chains, a missing `else`) is left intact.

### Reconciliation shapes

Three shapes are accepted, matched on the final statement of each branch:

```python
if c: x = A            # same-target assignment
else: x = B            #   -> __gm_cond = c; __gm_true = A; __gm_false = B
                       #      x = torch.where(__gm_cond, __gm_true, __gm_false)

if c: return A         # same-shape return
else: return B         #   -> ...; return torch.where(...)

if c: g(a, k=K)        # common call: same callee, same kwargs, same arity
else: g(b, k=K)        #   -> g(torch.where(__gm_cond, a, b), k=K)
```

The common-call form merges each differing positional argument with its own
`torch.where` and emits the call once; kwargs must be textually identical and
the callee texts must match. Branch values that are `None` decline (no tensor
selection exists for it), as does a branch pair mixing a call with a literal
(see below).

### `torch.where` versus `torch.cond`

`torch.where` is an ordinary call, so both operands are evaluated regardless
of the predicate. For symmetric values (bare names, pure arithmetic) that is
harmless and is what the pass emits. When a branch value contains a function
call, evaluating both sides would run a call the original program did not
run, which is not merely wasteful: it is unsound whenever that call is only
valid under its own predicate. For that shape the pass emits `torch.cond`,
whose lambda branches execute only the selected path:

```python
x = torch.cond(__gm_cond_0, lambda: f(a), lambda: g(b), ())
```

The selection is ordered by legality first and cost second: `torch.cond`
introduces branch-dispatch synchronization and disables CUDA Graph capture
for the region, so `torch.where` is preferred wherever it is legal. One gap
remains: a call paired with a literal. `torch.where` would speculate the
call, and `torch.cond` cannot return a Python literal, so neither form is
sound and the branch is left untouched, break included.

### Multi-statement branches and hoisting legality

When both branches end in the same call but carry setup statements before it,
the setups are hoisted to run unconditionally (predication computes both
paths). A hoisted setup must therefore be observationally neutral on the
untaken path. Two obligations apply, and failing either declines the whole
rewrite:

1. Control neutrality: no `return`, `raise`, `break` or `continue` anywhere
   in a setup, else a control transfer becomes unconditional.
2. Effect neutrality: every setup must be one of the licensed forms below.
   Anything else, in particular a non-idempotent observable write such as
   `self.counter += 1`, is declined and the break is left intact.

The licensed forms:

- A pure write to bare local names whose value contains no call. The value is
  recomputed, nothing escapes.
- An idempotent device move `x = x.to(...)` where the target is textually the
  receiver. Re-running it is a no-op.
- A lowered validation assert (`torch._assert_async(...)` produced by
  `TrapLoweringPass`). It is hoisted but re-gated on the branch predicate so
  it cannot fire on the untaken path: the check `C` becomes
  `torch.logical_or(torch.logical_not(cond), C)` for the true branch and
  `torch.logical_or(cond, C)` for the false branch. The `torch.equal` guard
  form (`__jac_tensor_eq_assert__`) computes its check inside the helper
  where no predicate can be injected, so its presence declines the rewrite
  rather than asserting unconditionally.
- An existence-guarded initialization, under the conditions below.

### The existence-guard license

`if not hasattr(X, "k"): X.k = init(...)` is the one licensed hoist that
creates state earlier than the original program would. The `hasattr` shape
alone is not sufficient; five conditions must hold:

- G1, shape: the guard has no `else` branch.
- G2, memoization: the body definitely assigns `X.k`, so the guard closes and
  re-execution is a genuine no-op. Without this the body re-runs on every
  call, and hoisting it would run a live write on the untaken path.
- G3, body neutrality: every other statement in the body is itself a neutral
  assignment. Only the memoizing write may contain a call (the initializer);
  arbitrary I/O smuggled in under a `hasattr` header is declined.
- G4, confinement: the attribute `k` is read nowhere in the module outside
  the rewritten region, including via string literals equal to `"k"` (which
  could feed `hasattr`/`getattr`/`setattr`). Early existence must not be
  observable by any code the pass can see.
- G5, initializer safety: every call in the memoizing write resolves to
  inspectable code that is pure and non-raising for the arguments this call
  site passes. A bare-name callee must resolve to a module-level function. An
  attribute callee such as `self.rope_init_fn` cannot be resolved from one
  module, but the dispatch-table idiom is still decidable: the candidate set
  is every function reachable through any module-level dict of local
  functions, narrowed by signature compatibility (a function the call would
  raise `TypeError` on cannot be the callee), and every surviving candidate
  must clear the purity check. A `raise` inside a candidate counts as
  unreachable only in the varkwargs-validation form (`if rope_kwargs: raise`)
  when this call passes no unexpected keyword. Purity is transitive into
  local helpers; unresolvable calls are opaque and decline.

### Caveat: speculated memoization is a state change, not a no-op

The existence-guard hoist runs the initializer on executions where the
original predicate would have been false, so the memoized attribute exists
earlier than the original program would create it. The `hasattr` guard makes
replay idempotent (running twice equals running once); it does not make
speculation invisible. What makes the hoist legal is confinement (G4): the
attribute is a private memoization slot no other code in the module can test
or read, so no observer inside the compiled module distinguishes "cached now"
from "cached on a later call". Two assumptions remain outside what the
analysis can discharge: an observer in another module (an external `hasattr`,
a `__dict__` or `state_dict()` walk, a subclass in another file) can still
see the slot early, and an attribute callee bound to something other than a
module-level dispatch table would not be seen by G5. The honest phrasing of
the guarantee is therefore equivalence modulo private memoization state.

## Deferred side effects: `DeferSideEffectPass`

A side-effecting call inside a compiled region forces a graph break because
it touches the Python runtime mid-graph. The pass defers such calls: the
effect is captured as data while the graph runs and replayed, in original
program order, after it. Two mechanisms exist because the two call shapes
break for different reasons.

`print(...)` is a plain global, so storing it in the graph is legal. The
call is rewritten to `__jac_se_emit__(print, (args...), {kwargs})`, which
appends a `(callee, args, kwargs)` triple to a process-global buffer.
`list.append` is a side effect TorchDynamo tracks and replays, so the append
costs no break; only the trailing `__jac_se_flush__()`, inserted before each
`return` of the compiled entry (and at the end of a body that can fall off),
touches the runtime, after all compute. The buffer is process-global rather
than function-local so it outlives a frame that exits by raising, which is
what lets the boundary guard below drain it.

`logger.X(...)` cannot use that path: TorchDynamo cannot trace a
`logging.Logger` method at all, even to store it, so buffering the bound
method only relocates the break. The Logger therefore never enters the
graph: at module load the bound method is registered to an integer slot
(`_gm_log_slot_N = __jac_log_register__(logger.X)`, inserted after the
top-level class holding the forward), and inside the forward only
`__jac_log_emit__(slot, (args...), {kwargs})` appears, ints and constants
that trace as a replayable append. A forward hook flushes the slot buffer
after the graph executes. This mechanism applies only inside `forward`
methods with a bare module-level receiver (not `self.`/`cls.`); anything
else falls back to buffer plus flush.

### Argument snapshotting

Buffered values must be captured at the original call site, not at flush. A
mutable positional argument is hoisted to `__gm_se_arg_N = <arg>` and buffered
as `__gm_se_arg_N.clone() if hasattr(__gm_se_arg_N, 'clone') else
__gm_se_arg_N`; the `hasattr` is resolved statically by Dynamo, so the clone
is a native in-graph op for tensors and a no-op for everything else. A later
in-place mutation therefore cannot corrupt the value the deferred call
observes. Literals are immutable and buffered as-is. Logger arguments cross
the opaque `log_emit` boundary and are constant-only by construction.

### Exceptional exits

Wrapping the body in `try`/`finally` is not usable: the flush is deliberately
untraceable, and TorchDynamo answers an untraceable call inside a `finally`
by abandoning the whole frame, one FX graph becomes zero, strictly worse than
the break being removed. Each path instead closes the gap from outside the
traced region. A `@torch.compile`-decorated function gets `@__jac_se_guard__`
prepended above `torch.compile`, so its `try`/`finally` is eager code Dynamo
never sees; the guard opens the region on entry and drains the global buffer
on every exit, raising or not. An `nn.Module` compiled at a call site gets a
`register_forward_pre_hook(__jac_se_region_open__)` /
`register_forward_hook(__jac_log_flush_hook__, always_call=True)` pair
injected after the `torch.compile(...)` assignment; `always_call=True` is
what makes the hook fire when `forward` raises, so buffered calls are
replayed before the exception propagates.

### Helpers defer to the caller's region

The runtime keeps a region depth, opened by the guard or the pre-hook.
`se_emit` buffers only while the depth is non-zero and performs the call
immediately otherwise. A helper inlined into a compiled caller therefore
emits no flush of its own (one would split the caller's graph from the
inside); its effects drain at the enclosing region's exit. The same helper
called from ordinary Python emits at its original point. The module-exit
sweep guards every compiled entry in a module that defers anything, not just
entries containing a deferred call themselves, because the caller of a
buffering helper is what must open the region.

## Scoped imports: `--graphmend-scope`

`--graphmend-scope pkg.a,pkg.b` (implies `--graphmend`) extends the
transforms to imported `.py` model code, the shape real Hugging Face models
take, where `torch.compile(model)` lives in the entry script and every break
sits in imported modules. `JacMetaImporter.find_spec` claims a plain `.py`
module when its dotted name falls under a scope prefix; the module compiles
through the full GraphMend schedule as one whole compiled region.

Not every import consults `sys.meta_path`: `trust_remote_code` models load
via `spec_from_file_location` plus `exec_module`. Every such path still goes
through `SourceFileLoader.get_code`, so `install_graphmend_loader_hook`
wraps that instead. Compiling from source there also sidesteps
`__pycache__`, so a `.pyc` written by a non-GraphMend run is never served to
a GraphMend one.

Safety properties: strictly opt-in (an empty scope claims nothing), `torch`
and `jaclang` are hard-denylisted so the interception can never break the
compiler or PyTorch itself, and a scoped `.py` the Jac compiler cannot
handle falls back to CPython's own compiler and runs untransformed rather
than failing the import.

## Evidence

`tests/compiler/passes/main/test_graphmend_trap_lowering.jac`,
`test_graphmend_ctrl_flow.jac`, `test_graphmend_side_effect.jac`, and
`test_graphmend_py_support.jac` assert detection tags and the generated
Python source for `.jac` and `.py` fixtures, including one decline test per
legality condition above, the emitted runtime-helper imports, and the
call-site entry-point resolution.
`test_graphmend_trap_integration.jac` and
`test_graphmend_where_integration.jac` (skipped without torch) drive the
transformed code through a counting Dynamo backend and assert the paper's
metric directly: each fixture fragments into two or more graphs without
GraphMend and exactly one with it. The trap tests additionally check that a
failing guard under a real eager-backend compile surfaces as the original
`ValueError` with the original message, with no marker text leaking to the
user; the predication tests additionally check that a hoisted, re-gated
assert stays dormant when its branch is not taken.
`test_graphmend_integration.py` (skipped without torch) does the same for
deferral: print and logger fixtures defragment to one graph, a buffered
argument mutated in place after its call site still prints the pre-mutation
snapshot, deferred output survives exceptional exits on both the guard and
the `always_call` hook paths, and a package imported under
`--graphmend-scope` is transformed while `torch` itself is not.
