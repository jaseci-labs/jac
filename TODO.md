  1. ✅ [RESOLVED] is_ref_arch is a syntactic heuristic that silently decides value-vs-reference semantics.
  type_facts_pass.impl.jac:89: an archetype is reference-semantic iff it has any method or any base class. Everything else emits as a bare by-value C struct
  (c_gen_pass.impl.jac:308-315 -- assignment copies). But on the bytecode backend every obj instance is a heap reference, Python-style. So a methodless obj Point { has x: int;
  } has aliasing semantics in the interpreter and copy semantics in emitted C -- and adding one method flips it. Your differential fixtures pass because none of them mutate a
  value-archetype after aliasing it. This matters doubly for the port: c2jac-lifted C structs come out methodless (→ value), then the idiom pack folds malloc(sizeof(T)) into
  a constructor, which implies reference identity. Classification this load-bearing should come from declared semantics or the real type system, not "has a method." (Per
  AGENTS.md I'm flagging this rather than fixing it -- it smells like a latent cross-backend divergence, worth a mutate-after-alias fixture on a separate branch to confirm.)

  2. ✅ [RESOLVED] RC and longjmp don't compose -- exception unwinding leaks.
  Confirmed in gen_try (c_gen_pass.impl.jac:929-): the handler branch restores control but never releases the interrupted scope's owned locals; scope_release_lines only fires
  on normal exit and returns. gen_raise payload ownership is likewise undefined (an owned rvalue payload is never released; nothing retains it either). At fixture scale this
  is invisible. But exceptions are CPython's primary control flow -- every error path -- and your own plan's highest-ROI tool (GOTO_LIFTER) exists precisely to convert
  CPython's goto-error-ladders into try/finally. That pipes the port's single hottest pattern straight into the emitter's weakest seam. The fix is architectural, not
  incremental: frames need to record owned locals so the handler can release them (landing-pad style), decided before GOTO_LIFTER ships.

  3. 🟡 [PARTIAL] Two parallel type systems, with name-keyed identity.
  TypeFacts is a syntactic re-inference living beside the real checker/TypeEvaluator -- the PLAN.md refactor consolidated duplication within the facts layer, but the
  facts-vs-checker split remains, and it has already drifted once (the expr_type_name divergence PLAN.md documents). RESOLVED: the name-keyed identity half.
  get_shared_type_facts / get_shared_layout_registry no longer merge first-wins by bare archetype name -- a shared TypeIdIndex assigns every archetype a program-unique
  `tid` (bare when unique across the module set so single-module emission is byte-identical; mangled per module on collision), and TypeFacts, LayoutRegistry, the emitted C
  struct/ctor/method/dtor/vtable names, runtime type ids, and every type reference (local decls, import aliases, cross-module returns) are keyed/resolved through it. Two
  modules defining Token or State now coexist as distinct structs with a diagnostic-free, behaviorally-verified differential (test_jac2c_name_collision), instead of one
  silently inheriting the other's ref-ness and fields. STILL OPEN: the deeper facts-vs-checker split (TypeFacts as a re-inference beside TypeEvaluator) remains its own
  consolidation task, independent of identity.

  4. ✅ [RESOLVED] Fidelity is tracked per-node, but there's no containment unit.
  The surrogate/twin-band design is genuinely good, but one __c_unsupported__ inside a function makes that function a runtime landmine in a module that imports cleanly -- and
  on the native lane, one surrogate breaks static call resolution for the whole module, so Tier-B contaminates at module granularity there. There's no quarantine story: e.g.,
  "this one function stays as original C reached via clib until its Tier-B sites burn down," or at minimum a stub that traps at call time with the diag reason. Relatedly,
  the W-band conflates stylistic infidelity (cast elided, W4201) with behavioral change (W4206 drops static-local persistence; W4205 drops volatile) -- lenient ingest will
  happily run code that computes wrong answers with only a compile-time warning. Behavior-changing lowerings deserve their own band or a runtime trap, especially if you adopt
  run-then-refactor.

  5. ✅ [RESOLVED] Ingestion is TU-shaped while emission is program-shaped.
  jac2c has the whole-program architecture -- import graph BFS, shared layout/facts, transitive externs. c2jac lifts one file in isolation: no cross-TU symbol registry, so
  extern functions in lifted code dangle and lifted modules can't call each other. The plan knows this (T2 project mode) but it's worth naming as the structural asymmetry:
  the port direction is the one missing the multi-module architecture. Same gap: the fidelity report is a stdout comment header, not a sidecar artifact -- no machine-readable
  provenance exists for incremental re-lifts, upstream sync, or the AI loop to key off.

  The medium ones

  1. ✅ [RESOLVED] Fake-libc placeholder widths. bindgen already works around pycparser's fake libc defining size_t/stdint types with placeholder widths (it matches by name before
  resolving -- a documented dodge). The lifter uses the same fake headers, so sizeof, integer-width, and struct-layout semantics in lifted code inherit placeholder truth.
  CPython is saturated with Py_ssize_t/size_t arithmetic. The choice -- fake headers (wrong widths, small surface) vs real system headers (correct, but a huge declaration
  surface the lifter must tolerate) -- is undecided and should be made once, deliberately. A curated LP64-correct porting libc (natural companion to the jacport.h idea)
  resolves it.

  2. 🟡 [PARTIAL] The round-trip oracle shrinks exactly as the lift improves. jac2c's emittable subset is roughly C-shaped Jac (no lists/dicts/str methods/f-strings/match). The idiom
  pack's entire purpose is to emit idiomatic Jac -- which jac2c then can't re-emit, so the round-trip differential goes dark on precisely the translations that most need
  verification. Either commit to growing jac2c's subset in lockstep (expensive, and it's not on the port's critical path), or re-point the per-function oracle at
  bytecode-backend execution vs. cc-compiled original C. The second is cheaper and keeps the proof engine alive for arbitrarily idiomatic output.

  3. 🟡 [PARTIAL] Whole-program-only emission with a process-global type registry. Exception type ids come from a mutable JAC_TYPE_REGISTRY singleton, and dense type-ids are assigned per
  emit -- stable only within one whole-program run. Fine for the current design, but it forecloses separate compilation and incremental re-emission, and shared facts/layout
  are rebuilt O(program) per change. A 600-module jacpython with any edit-compile loop will feel this; worth at least keeping ids derivable (hash-based) rather than
  order-assigned so the door stays open.

  Housekeeping

  ❌ [OPEN] The tests directory naming actively misleads (tests/compiler/c2jac/ holds the jac2c emission tests and fixtures too); IMPLEMENTATION.md describes the retired two-hop
  architecture; exception payloads are untyped void* bound-then-ignored, so except X as e binds a name that carries nothing -- fine now, but it's the seam where real exception
  objects will eventually have to land.

  If I had to pick the two to act on before any CPython code flows: #2 (decide the unwind-cleanup design before GOTO_LIFTER exists, since retrofitting it after thousands of
  lifted try/finally blocks is miserable) and #3's name-keying (a one-time switch to qualified identity while the fixture corpus is still small enough to migrate trivially).
  #1 deserves a confirming fixture on its own branch first, since it may be a deliberate-but-undocumented semantic choice rather than an oversight.

  > Status check: of the three flagged there, #2 (unwind-cleanup) and #1 (value-arch alias) are now RESOLVED on this branch; #3's name-keyed-identity half is RESOLVED on branch jac2c-a3-name-keyed-identity (module-qualified tids); its facts-vs-checker-consolidation half remains OPEN.

  1. ✅ [RESOLVED -- fixture level] The lifter is compile-proven, not behavior-proven -- the proof asymmetry is backwards.
  The ~55-fixture breadth matrix asserts that lifted Jac recompiles with zero errors and emits exactly the expected diagnostic codes. It never runs the lifted code. The only
  end-to-end behavioral evidence for the entire ingestion leg is the minilib round-trip; scaling the differential harness across the fixture corpus is explicitly deferred.
  Meanwhile the emit leg (jac2c) -- which isn't even on the port's critical path -- has the luxurious three-way differential oracle. So the component carrying the whole port
  thesis has the weakest semantic verification in the repo. The do-while desugar, switch lowering, for-promotion continue analysis, enum verdicts: all proven to parse and
  type-check, none proven to compute the right answers. Cheapest fix ties into the run-then-refactor idea: execute every lifted breadth fixture on the bytecode backend and
  diff against the cc-compiled original C. The fixtures and drivers already exist; only the harness leg is missing.

  2. 🟡 [PARTIAL] The entire ingestion leg is exempt from the type checker.
  .jacignore lines 271–282 list all ten cfront/ modules, cast_load_pass.jac + its impl, and bindgen.jac; compiler/ownership.jac is in there too (line 348). So the tool that's
  going to chew through 260k LOC of CPython has no static safety net -- regressions surface only through fixtures, which per point 1 are compile-only. Notably, this branch
  just fixed the same problem for the emit side (commit 956eaf28d brought the c_gen/type-facts/ownership passes under jac check by narrowing module.gen.X with isinstance
  instead of ignoring the files) -- the identical treatment is owed to cfront, and the precedent for how to do it now exists in-tree.

  3. ✅ [RESOLVED] Local green is not the full oracle.
  The differential test's strongest leg -- na-compiled binary vs jac2c-emitted-C binary -- was gated on a linkable musl and only ran in CI; locally it printed a skip line. And
  the C-execution legs silently degrade to structural checks if no cc is on PATH. RESOLVED: the na leg now emits its object in-process and links it with the same system `cc`
  the C leg already requires (dynamic libc, `-lm`), instead of static-linking a vendored musl via `jac nacompile`. So the two compiled backends are compared wherever a `cc` is
  on PATH -- locally and in CI alike -- and the leg asserts `ran_any` instead of printing a skip line. (`test_jac2c_differential.jac`, third test.) The residual C-leg cc-absent
  degradation remains, but that only fires on a machine with no C compiler at all, where neither backend can be compiled anyway.

  4. ❌ [OPEN] The D4 native lane's real risk is a specific list, not a risk-register row.
  jac-py/PLAN.md treats "na maturity" as one line item. But accumulated experience across the sibling worktrees gives a concrete inventory of na landmines, and jacpython's
  core is shaped exactly like the code that hits them: string concat drops NUL bytes and len() is strlen (fatal for marshal/bytes/code-object work), dict-return ICEs,
  list[int] subscript gaps, method calls on T|None receivers silently dropped, the external field-write header-offset bug, scalar globals not persisting across calls. The
  PyObj core is precisely binary-buffer + dict + optional-receiver code. I'd turn that list into the T7 lint gate's first fixture set -- a "known na cliffs" conformance file
  that jac-py CI compiles natively from day one, so the dual-substrate bet is continuously validated instead of discovered broken at P7.

  5. ✅ [RESOLVED -- by design] The repo's own hygiene machinery is mildly hostile to machine-generated code at scale.
  Three interacting facts: the deslop CI rules strip all comments from core .jac (which would delete c2jac provenance headers -- jac-py/* is already excluded in jac.toml, and
  usefully that exclude survived the rotatingtree deletion, so the staging area is safe); jac format --lintfix has a documented history of semantically breaking rewrites (the
  getattr null-safe rewrite, with-entry local hoisting causing double-frees); and the format hook can OOM this box by compiling the compiler in parallel -- the working commit
  recipe is SKIP=jac-format with pre-stripped comments. Thousands of lifted files flowing through those hooks will find new failure modes; the port pipeline should own its
  formatting at emission time and keep jac-py out of lintfix's jurisdiction.

  6. ❌ [OPEN] The porting target itself is a moving alpha.
  reference/cpython is 3.16.0a0, unpinned. The plan's own P0 says pin to a 3.14 release tag, but the decision was never executed -- which means every calibration made so far
  (the three lifted fixtures, the LOC survey, the bucket decomposition in PLAN.md §3) is against source that drifts under you. This is a five-minute decision with compounding
  value; I'd make it before the first raw-TU experiment, since Tier-B density numbers against an alpha won't be comparable to numbers against the pin.

  One small closing observation: the # c2jac: fidelity header being a comment block in stdout rather than a sidecar file means the report is gone the moment output is piped
  to a file and reformatted -- the same fact from the architecture list, but the practical consequence is that today there is no durable record anywhere of which sites in a
  lifted file are best-effort. For a one-file demo that's fine; for a burndown metric across 400 files it's the first thing project mode needs.

  1. ❌ [OPEN] D2 has a hidden dependency closure: you can't run Lib/test until unittest runs.
  "A pinned subset of CPython's own test suite passes" sounds like a per-module gate, but every test_*.py file imports unittest, which transitively drags in re (so_sre),
  traceback (so frame objects and sys._getframe-adjacent introspection), os, io, inspect, functools, collections… Historically this is the reimplementation trap -- Jython and
  early PyPy both hit it: the test runner's bootstrap set is ~50 stdlib modules that must all work before conformance measurement begins. Your plan half-knows this (the
  harness "runs module-level differential tests before jacpython can import"), but I'd promote that from stopgap to primary strategy: a minimal test-vector runner shim (not
  real unittest) should carry you through P2–P4, and "real unittest boots" should be an explicit named milestone around P5 -- it's a bigger deal than pystone.

  2. ❌ [OPEN] Double interpretation makes conformance CI a throughput problem, not just a correctness one.
  jacpython on the bytecode backend is Python interpreting Python -- expect 100×+ slowdown. A single CPython test file can run tens of thousands of cases; the full ratchet
  under double interpretation is plausibly a multi-day run. PyPy learned this the hard way and ran most tests only on translated builds. Design the harness for it now:
  per-case timeouts, per-module sharding, a small always-on PR subset with nightly full runs, and treat getting jacpython itself through nacompile as a CI-infrastructure
  investment (fast conformance runs), not just the D4 trophy at the end.

  3. ❌ [OPEN] You can re-sequence P4 and P5 -- execute .pyc before you can compile.
  D1 currently gates on the whole front end (tokenizer → parser → symtable → compile → marshal). But the object core plus ceval can run real programs today's CPython
  compiles: have the host compile() the source, marshal it, and have jacpython execute the code object. That collapses M1's dependency chain to P3 + P5 and turns the entire
  front end into parallel, non-gating work -- while giving you an exquisite oracle for free (the same .pyc executed by both interpreters, which is also what makes the lockstep
  lltrace idea work). The plan already borrows the host tokenizer; borrowing the whole compiler during bootstrap is the same move with much larger payoff. Early PyPy did
  exactly this.

  4. ❌ [OPEN] RC hands you an advantage no other Python reimplementation had -- and one external dependency you should file today.
  PyPy's single biggest compatibility tax was that its GC broke CPython's deterministic finalization: __del__ timing, files closing on scope exit, weakref callbacks --
  thousands of tests implicitly depend on refcount semantics. Jac is RC-based, so jacpython gets CPython-faithful finalization for free; you're structurally better positioned
  on the long tail than PyPy was, and it's worth exploiting (don't design that away, e.g. by adding deferred-release optimizations to the runtime later). The flip side:
  reference cycles. With deep-release semantics still constrained on the jaclang side and no cycle collector, test_gc and every cycle-leaking suite is permanently out of
  reach -- and that's a dependency on someone else's roadmap. The plan says "file jaclang issue early"; concretely, that issue is the longest-lead-time item in the entire
  project and it isn't filed. I'd do it this week, with jacpython named as the driving consumer.

  5. ❌ [OPEN] Decide now whether jacpython is a living implementation or a demonstration.
  Everything about T3's value (regenerable parsers/eval loops), the provenance-DB idea, and the upstream-sync playbook hinges on one strategic question the plan defers to P8:
  does jacpython track CPython releases, or is it pinned forever at 3.14? If it's a demo, T3 regenerability is over-engineering and hand-porting generated code is fine; if
  it's living, the content-addressed function-level translation DB stops being a nice-to-have and becomes core architecture, and you should vendor the exact Tools/
  (cases_generator, clinic, peg_generator) from the pinned tag -- those metaprograms are refactored aggressively between CPython versions, and retargeting a moving one twice
  is worse than retargeting a frozen one once. One housekeeping line while you're at it: the port is a derivative work of CPython, so jac-py needs the PSF license carried
  alongside (and MIT attribution if you pull PyPy-sourced pure-Python implementations, which mixes fine).

  6. ❌ [OPEN] Name the failure mode: tooling-forever.
  Candidly, the revealed preference of the last several months is beautiful substrate work -- the TypeFacts extraction, cross-module vdispatch, transitive chains -- while
  jac-py/ sat at a plan and zero ported modules (the one staged port got deleted as slop). The plan's thesis ("treat the port as a tooling problem") is right, but
  tooling-first strategies fail by never declaring the tooling done. The antidote is a demand-driven forcing function: a standing ratchet that ingests one raw,
  fully-preprocessed CPython file per week into jac-py regardless of tooling state, with its Tier-B density recorded on a burndown. Tool gaps then get discovered and
  prioritized by what the target actually needs -- which is also the only way to find out whether GOTO_LIFTER's pattern-directed subset covers real CPython, the single
  assumption the entire effort-shape estimate in §11 rests on.

  ❌ [OPEN] Layer 0 (P3, day one): keep the harness on the host, replay at the code-object boundary

  The trap only exists if the test runner must run inside jacpython. It doesn't. Run the test file under host CPython with an AST-instrumented shim: rewrite each
  assertEqual(expr, expected) so the harness captures the source expression, has the host compile it to a code object, ships that code object (marshal) plus the host-computed
  expected value (repr/marshal) across to jacpython, executes it there, and compares. jacpython's required surface for full object-core conformance measurement is then just:
  object core + ceval + marshal-load. No unittest, no re, no io, no parser -- this composes exactly with the .pyc re-sequencing from before, and it's why that re-sequencing
  matters so much: the narrowest boundary is a code object and a serialized expectation, and everything on the far side of it can be host machinery. A large fraction of
  test_int/test_dict/test_list asserts are self-contained expressions over literals, so coverage from this alone is substantial. Fixture-dependent cases (setUp state,
  mutation across cases) fall out of scope for this layer -- that's fine; they're what the later layers pick up.

  ❌ [OPEN] Layer 1 (P3–P5): proxy the closure instead of porting it

  Here's the structural advantage the plan under-uses: during bootstrap, jacpython runs inside a host CPython process (the bytecode backend). So any stdlib module jacpython
  can't provide yet can be a proxy module -- a thin shim that wraps host objects in PyObj shells and delegates calls through the substrate boundary. import re inside jacpython
  resolves to a proxy around the host's re; same for io, os, traceback, _weakref. This is precisely PyPy's "mixed modules" play and Jython's Java-delegation play, and your
  plan already gestures at it for the tokenizer and importlib (§12.2) -- the move is to generalize it to the entire bootstrap closure. Result: real, unmodified test_*.py files
  can run under jacpython immediately, with proxies carrying whatever the port hasn't reached.

  The obvious danger is that proxies mask incompatibility -- a test "passes" because the host's re did the work. So the ratchet becomes two-dimensional and honest about it: a
  test is green-with-scaffolding if it passes with proxies in its import closure, and conformant only when that closure is proxy-free. Both counts go on the dashboard; only
  the second is the D2 metric. The de-proxy burndown is the port's progress meter, and it self-prioritizes: sort modules by how many scaffolded-green tests they'd flip to
  conformant, and that's your porting order for P6 -- demand-driven, not guessed.

  One design consequence worth deciding in the P3.0 spike, not later: the object model needs a PyHostProxy(PyObj) archetype (wraps a host object, dispatches slots through it)
  from the beginning. It's small, but it touches the same slot-dispatch architecture as PyUserObj, so it should be born in the same design decision rather than bolted on.

  ❌ [OPEN] Layer 2 (P4–P5): a shim unittest for the middle distance

  Between "expression replay" and "real unittest boots," carry a ~200-line minitest -- TestCase, assertEqual/assertTrue/assertRaises, method discovery, zero imports beyond
  builtins -- installed as sys.modules["unittest"], plus a stub test.support whose decorators (cpython_only, requires_resource, bigmemtest…) all resolve to skip. That lets
  unmodified test files whose usage stays inside the shim's surface run without the proxy layer in the loop, which matters when you're specifically trying to certify a module
  proxy-free but the real unittest's own closure isn't clean yet. Two rules learned from everyone who's done this: run test files standalone, never via regrtest (regrtest's
  resource/reporting machinery multiplies the closure), and never grow the shim past what a real test file forces -- it's scaffolding with a demolition date.

  ❌ [OPEN] Layer 3 (P5): "unittest boots un-proxied" as a named milestone

  Compute the actual closure mechanically today -- run python -c "import unittest, test.support" under the pinned 3.14 and diff sys.modules -- so the bootstrap set is an
  explicit manifest, not folklore. Most of it is pure Lib/ Python (py2jac territory); the genuinely load-bearing C is short: _sre,_io (note _pyio exists -- the pure-Python io
  -- and is the right first target), a posix subset,_collections/itertools/_functools/_operator, _weakref, a serialized_thread stub. _sre is the hard one and your plan
  already resolved to port it (§12.6) -- the closure analysis just tells you it's a P4-priority port, not a P6 one. When that manifest runs proxy-free and real unittest
  executes a real test file end to end, that's the milestone -- and it's a more meaningful "the interpreter is real" moment than pystone, because unittest exercises classes,
  exceptions, decorators, context managers, and introspection all at once.

  The through-line: the closure never blocks measurement, and measurement burns down the closure. Layer 0 gives you conformance signal before jacpython can even import; Layer
  1 gives you real test files with an honest scaffolding ledger; Layers 2–3 retire the scaffolding on a schedule the dashboard itself dictates. The only thing I'd treat as
  urgent is the P3.0 design hook (the proxy archetype), because it's the one piece that can't be retrofitted cheaply.

---

## Status legend (added 2026-07-13)

- ✅ RESOLVED -- fixed on branch `jac2c-value-arch-alias-divergence`
- 🟡 PARTIAL -- partially addressed
- ❌ OPEN -- not addressed (mostly jacpython / D-track scope, out of this branch)

## Evidence for RESOLVED items

- __A1 value/ref semantics:__ `is_ref_arch` now defaults to ref-semantic and flips only on an explicit `@__jac_value__` stamp; c2jac stamps lifted C PODs (commit `168f07a9c`). Mutate-after-alias aliasing is covered by fixtures `obj_value_alias.jac` / `test_jac2c_value_arch.jac`.
- __A2 RC + longjmp:__ `c_gen_pass.impl.jac` now emits a landing-pad / cleanup frame that releases owned locals on the longjmp path (`scope_release_lines`, lines ~637–638, ~1069–1070).
- __A4 fidelity containment:__ new `cfront/fidelity.jac` splits STYLE/BEHAVIOR/HOLE bands; `band_quarantines()` quarantines the containing function for behavior/hole sites; `cfront/report.jac` records `quarantined_functions`.
- __A5 cross-TU ingestion:__ new `cfront/project.jac` adds multi-TU lift with a cross-TU symbol registry; `cfront/report.jac` writes `*.c2jac.report.json` sidecars for re-lifts/aggregates/AI loop; commit `168f07a9c` adds transitive cross-module emit.
- __A3 name-keyed type identity:__ ✅ RESOLVED by `e344d5ffe` -- module-qualified `TypeIdIndex` identity is shared across TypeFacts, layout, emitted symbols, runtime ids, and cross-module references; collision coverage is in `test_jac2c_name_collision.jac`.
- __A6 LP64 libc:__ new `cfront/lp64_scalars.jac` is a curated LP64-correct scalar map (`size_t`/`Py_ssize_t` → u64/i64), name-matched ahead of alias resolution.
- __B1 behavior-proven:__ `test_jac2c_runtime.jac` now executes lifted fixtures on both the cc-linked binary and the stock Jac interpreter and diffs them (`interpreter_run` / `link_and_run`).
- __B5 hygiene:__ `jac.toml` already excludes `jac-py/*` from deslop/format; the `SKIP=jac-format` + pre-stripped-comments recipe is intact; this branch did not regress it.
- __B2 ingestion type-check:__ ✅ RESOLVED -- untyped `jaclang/vendor` modules are classified as foreign `Any`; C-ingestion and ownership files are no longer ignored by the checker. Focused checker gate: 13/13; `test_bindgen.jac` + `test_cast_ingest.jac`: 31/31.
- __Foreign-Any propagation:__ ✅ RESOLVED -- iteration, tuple destructuring, subscripting, and operators preserve foreign `Any`, while ordinary `Any` remains on its existing path. Regression suite: 6/6, with positive and negative controls.

## Recent work completed (2026-07-14)

- Checker fix split onto `foreign-any-checker-fix` as `ed32b62c2`, then brought into this branch as `606404ba4`.
- B2 ingestion/type-check narrowing committed as `a055aa045` and pushed to `origin/jac-python` for PR #6973.
- Broader c2jac breadth/slice runs still expose unrelated fixture issues: comments passed directly to pycparser in `struct_shape.c`, and unpreprocessed directives in `cpython/rotatingtree.c`; no changes made here.

## PARTIAL items

- __A7 round-trip oracle:__ emit-leg differential now runs (cc-binary vs interpreter), but jac2c still can't re-emit all idiomatic Jac and the oracle was not re-pointed at bytecode-backend execution.
- __A8 type registry:__ `exception_type_id` is now sha256 hash-based (derivable/stable); emission is still whole-program-only (no separate compilation).

## OPEN (not on this branch)

- __B3 local oracle:__ ✅ RESOLVED -- na-vs-C runtime leg now links the na object with the host `cc` (dynamic libc) so it runs locally, not just CI (`test_jac2c_differential.jac`).
- __B4, B6, C1–C6, Layers 0–3:__ jacpython / D-track items -- `jac-py/PLAN.md` is still design/scoping (one module ported), `reference/cpython` still `3.16.0a0` (P0 pin unexecuted).
