## Already moved (don’t re-do)

Compare protocol (`NotImplemented`, cross-type `TypeError`, `True == 1`), hash `(-1,)`, Layer-1 probes, CI manifest drift, libtest stdout helper - those were the high-leverage Layer-1 honesty fixes.

**Also done on this branch:** native str/int/float `repr()` (ceval dispatch), P3 runtime parity probes (M11), `PySlice` + `PyComplex` imports in `marshal_reader.jac` (Layer-0 `test_int` 119 + `test_str` 345), getplatform libtest wiring, native str/float/bytes `hash()` in `pyhash.jac`, standalone SipHash secret (`PYTHONHASHSEED` / LCG / `os.urandom`, no ctypes), P2 wave-4 `pystricmp` lift sync + stronger gates, set subset/`isdisjoint` element-`==` (M9), bisect/heapq JacPython libtest shims, P5 `type_ready` wired into class construction, bulk Objects/ c2jac waves (P3.1c-P3.2e, 44 manifest stems), native ``PyRange`` deepen (len/contains/index/==/attrs), native ``PyByteArray`` deepen (slice/concat/mutate/bytes==), native str/bytes method surface (`PyStrMethod` / `PyBytesMethod` + deepened unicode/ctype/bytes_methods leaves), native gen `gi_running`/`gi_suspended`/`gi_frame` + close probes, native ``PyMemoryView`` + `memoryview()`, native `enumerate`/`reversed`, native `weakref` shim module, `PyIter` host-boundary drain, ``__slots__`` layout + member descriptors (`type_slots.jac` + `finalize_class_slots` / `PyMemberDescr` type-dict install), Band 5 ``__slots__`` codegen oracles, deepened odict/structseq leaf helpers.

---

## Tier 1 - Do first (biggest correctness + unlocks more tests)

### 1. ~~Native `repr()` for str / int / float (FIXME H3)~~ ✓

**Done:** `str_repr`, `int_repr`, `float_repr` wired in `ceval.jac` before host fallback.

---

### 2. ~~Wire `getplatform` into the libtest shim (FIXME H4/H5)~~ ✓

**Done:** `platform.platform()` → `Py_GetPlatform()` from `jacpython/getplatform.jac`; `system`/`machine` shims query host CPython (outside getplatform port). `can_run_jacpython_libtest` documents facade vs staged oracle split.

---

### 3. ~~Investigate Layer-0 `test_int` ratchet (114 vs 119)~~ ✓

**Root cause:** `marshal_reader.jac` called `PySlice(...)` in `read_slice()` without importing `PySlice`.

**Fix:** add `PySlice` to `marshal_reader.jac` imports. Gate reports `test_int passed=119`.

---

### 3b. ~~Layer-0 `test_str` complex-format ratchet (341 vs 345)~~ ✓

**Root cause:** `read_complex()` built `PyComplex(...)` without importing `PyComplex`.

**Fix:** add `PyComplex` to `marshal_reader.jac` imports. Gate reports `test_str passed=345`; full P3 Layer-0/1 ratchet green.

---

## Tier 2 - High value, more work (standalone JacPython)

### 4. ~~Native str/float/bytes `hash()` (FIXME Critical #1)~~ ✓

**Done:** SipHash13 + `_Py_HashDouble` ported to pure Jac in `pyhash.jac`. SipHash keys from process-local `PYTHONHASHSEED` bootstrap (LCG / zero / `os.urandom`). `bytes_hash_data` routes `bytesobject.jac` through the same machinery; Layer-1 bytes hash probe passes.

---

### 5. ~~Runtime parity in `test_p3_object_core_gate` (FIXME M11)~~ ✓

**Done:** `layer0_replay_p3_runtime_gate.jac` + manifest `runtime_probe` entries.

---

## Tier 3 - Correctness hygiene (prevent silent wrong code)

### 6. ~~P2 wave 4 - `pystricmp` NUL semantics + stronger gates (FIXME M1-M5)~~ ✓

**Done:** `pystricmp` reclassified `lift` in wave-4 manifest; staged oracle byte-synced to lifted corpus (NUL-terminated loop). Wave-4 staged-sync gate now mirrors wave 2/3 (manifest enumeration + lift byte-match). Added boundary oracles: empty strings, prefix mismatch.

---

### 7. ~~Set subset compare with element `==` (FIXME M9)~~ ✓

**Done:** `_set_contains_elem` + `_obj_eq_bool` in `objects.jac`; `_pyset_richcompare_na`, `set_lookup`, `isdisjoint`, and `in`/`__contains__` route through element `==`. Regression in `pyc_first.jac` (identity-keyed `AlwaysEq` user objects).

---

## Tier 4 - Explicitly later (your deferred list)

### 8. ~~bytes native hash / SipHash secret policy~~ ✓

**Done:** `bytes_hash_data` in `pyhash.jac`; `bytesobject.jac` uses SipHash13 via shared process-local secret bootstrap (same seam as str hash). Removed host `::py::` delegate.

---

### 9. ~~bisect/heapq JacPython~~ ✓

**Done:** `jacpython/_bisectmodule.jac` + `_heapqmodule.jac` facades; `layer_p2_libtest.jac` registers `bisect`/`heapq` stdlib shims; four libtest snippets marked `jacpython_capable`; conformance ratchet extended to `_bisectmodule` + `_heapqmodule`.

---

### 10. ~~Full Objects/ lift, heap types (P5)~~ ✓

**Done:**

- **P5 heap types:** `type_ready()` wired into `make_pyclass_from_map`; `PyClass.tp_flags` records READY state; `enum` removed from `layer3_force_host` force-proxy list.
- **Bulk Objects/ c2jac waves:** curated corpus → `Objects/_lifted/` → `jacpython/*.jac` → probes for **44** `c2jac_objects_wave` stems (P3.1c-P3.2e). Includes prior cores (bool/slice/abstract/tuple/long/type/exceptions/bytes/list/dict/set) plus method/descr (P3.2b) and remaining Objects stems (float/complex/range/enum/cell/func/iter/class, code/module/weakref/bytearray/memory/frame/gen/odict, union/namespace/capsule/structseq/file/call/bytes_methods/picklebuf/genericalias/typevar/interpolation/template/object/unicodectype/unicode). Gate: `test_p3_object_core_gate.jac` lift ratchets + M11 runtime probes.

**Still deferred (not Tier 4 bar):** deep algorithm ports beyond curated helpers (full unicode, timsort, real GC weakref, etc.).

---

## Next up (post-TODO)

1. ~~**Deepen Objects cores**~~ ✓ - native range/bytearray/str-bytes methods; gen/frame attrs; memoryview; enumerate/reversed; weakref shim; PyIter drain; odict/structseq leaf helpers (see Tier 4 / Also done).
2. ~~**Full `PyType_Ready` slot lifecycle**~~ ✓ - ``type_slots.jac`` + ``finalize_class_slots`` layout; ``PyMemberDescr`` type-dict install; instance ``__dict__`` omits slot members; Band 5 ``__slots__`` codegen oracles (`compiler_slice` / `layer9`).
3. ~~**Standalone SipHash secret**~~ ✓ - `pyhash.jac` boots keys from `PYTHONHASHSEED` (CPython LCG / zero / `os.urandom`); no embedding `_Py_HashSecret` ctypes shim

Post-TODO queue is clear of the three axes above. Further work is opportunistic deepen / Band 6+.

### Parked (do not block Band 10)

- **Band 10 `CALL_FUNCTION_EX`** - codegen + `compiler_slice` / `layer9` / VM fixtures landed
  this session (`BAND10_SLICE_LEARNINGS.md`). Ship without waiting on the parser.
- **Parser: trailing `**` after named kw** - native PEG drops `**d` in `g(a=1, **d)` /
  `g(*a, b=1, **d)`. Workaround: `g(**d, a=1)`. **Upstream:**
  [jaseci-labs/jac#8473](https://github.com/jaseci-labs/jac/issues/8473). Fix on a
  **separate parser branch** only; do not mix into heapq / Band 10 / deepen PRs.

### Suggested parallel workstreams (distinct file ownership)

1. ~~**Finish heapq/bisect product path**~~ ✓ - native jacpython facades (`_p2_*`, no `::py::`); Modules stay C-API hand oracles; staged-sync + facade parity gates.
2. ~~**Parser #8473**~~ ✓ - trailing `**` after named kwargs (`pa_join_sequences`); merged onto `jac-python`.
3. ~~**P2 leaf deepen / `_stat` / `_opcode` facades**~~ ✓ - native `jacpython/_statmodule.jac` + `_opcodemodule.jac`; libtest shims + facade parity; `opcode_meta2jac` emits `OPCODE_HAS_*` classifiers.
4. ~~**Compiler deferral slice: try/except/finally multi-handler**~~ ✓ - `visit_try_except_finally` chains N handlers (typed/bare), else, finally; nested try in body/handler publishes extents + inline enclosing epilogues; oracle-parity gates in `compiler_slice` / `layer9` (247 + 188). Except-as binding in the finally path remains deferred.

---

## PR #6973 review findings (2026-08-22)

Full per-area reports: `/tmp/review_findings_{compiler,runtime,corpus}.md`. All headline
claims below re-verified against source by hand. Order = fix priority.

### A. Verified bugs (fix before merge)

1. **`jac-py/jacpython/objects.jac:1591` `slice_indices()` — missing zero-step guard.**
   No `step == 0` check; with step 0 `_slice_objs`'s negative-step loop (`i + 0 == i`)
   hangs the VM / grows memory unboundedly. Reachable via `l[5:1:0]` and
   `del l[5:1:0]` (`mp_del_subscript`, objects.jac:673). CPython raises
   `ValueError: slice step cannot be zero`. **Fix:** raise that error when
   `step == 0`; add oracle test.

2. **`.github/workflows/ci.yml:665-673` — P3 gate steps hardcode dev-machine paths.**
   `JACPYTHON_CPYTHON=/home/jac/.local/bin/python3.14` (author's home dir,
   nonexistent on runners) and `runtime_gate.py`/`replay_gate.py` run
   `REPO_ROOT/.venv/bin/jac` (runtime_gate.py:16), which CI never creates — CI only
   installs `jac/zig-out/bin/jac`. These two steps cannot pass on GitHub CI.
   **Fix:** resolve CPython from PATH/`python3` action input, and point gates at the
   jac-kit-installed binary (or make them skip loudly, not fail).

3. **`jac/jaclang/langserve/impl/engine.impl.jac:640` — copy-paste f-string bug +
   scope creep.** `node_info += f"'\n'placement: ..."` emits literal apostrophes
   around a real newline in LSP hover text (sibling at :619 is correct). Also tags
   every symbol `'inferred'` unconditionally. Whole hunk is codespace hover
   decoration unrelated to jac-py. **Fix:** revert hunk or correct to
   `f"\nplacement: ..."` on its own branch.

4. **Bool-index inconsistency across sequence subscripts** (objects.jac).
   `PyList.mp_subscript` (:635) uses `to_index()` (accepts bool); `PyStr.mp_subscript`
   (:285), `PyBytes.mp_subscript` (:324), `PyTuple.mp_subscript` (:588) reject via
   `index.t != "int"`, so `"abc"[True]` fails where CPython returns `'b'`.
   **Fix:** route all four subscript paths through `to_index()`.

### B. Duplication (hoist into shared helpers)

1. **Richcompare op→bool ladder copied 10x**: objects.jac (PyInt/PyStr/PyFloat/
   PyBool x2), longobject `_richcompare_from_sign`, bytesobject/listobject/tupleobject
   `_compare_sizes`/`_compare_ints`, setobject. One shared
   `_bool_from_cmp(cmp: int, op: int)` in abstract_protocol replaces all.

2. **Truth-of-comparison-result helpers 4x**: `abstract_protocol._object_is_true`,
   `abstract_protocol._richcompare_to_bool`, `dictobject._richcompare_true` (pure
   alias), `objects._richcompare_truth` — with subtly different error semantics
   (-1 tri-state vs silent False). Consolidate to one tri-state helper.

3. **P2 wave harnesses are copy-paste with real strength drift**:
   `tools/test_p2_corpus_wave{2..11}_gate.py` (10 near-identical 79-line files),
   `tools/lift_p2_corpus_wave{2..11}.py`, `tools/p2_conformance_wave{2..11}_gate.py`
   (waves 2-3 assert less than waves 4-11 — weaker gating by accident of copy timing;
   wave10 checks `oracle_tests` + staged `.jac` existence, wave2 doesn't).
   **Fix:** one parameterized harness iterating `tools/p2_corpus_wave*/manifest.json`
   (the consolidated `.jac` harnesses already do this — follow that pattern), and
   apply the wave10-strength asserts to all waves.

4. **Wave/stem inventory maintained in four lockstep-by-hand places**:
   `manifest.json`, `tests/conformance_manifest_waveN.json`,
   `tools/p2_staged_manifest_waveN.json`, plus hardcoded `_expected_stems(wave)`
   if-chains duplicated verbatim in tests/test_p2_waves_staged_sync.jac:48,
   test_p2_waves_module_oracles.jac:71, test_p2_waves_corpus_density.jac:48.
   Derive expected stems from the corpus manifests instead.

5. **Misc duplicated glue**: `_signed_hash` (tupleobject.jac:50 = setobject.jac:25 =
   inlined in abstract_protocol `_hashkey_digest`); `_Py_SwappedOp = [4,5,2,3,0,1]`
   literal re-spelled in ceval.jac:2286 vs abstract_protocol.jac:13; NB_* binop kinds
   used as bare magic ints (0..12) throughout `nb_binop`/`py_binop` while Py_LT..Py_GE
   got named globs — define NB_ADD.. once.

### C. Dead code shipped as runtime (bloat)

1. **~25 "lifted" stub modules under jac-py/jacpython/ have zero callers**
    (repo-wide grep verified): iterobject, genobject, frameobject, enumobject,
    weakrefobject, odictobject, bytearrayobject, memoryobject, genericaliasobject,
    unionobject, typevarobject, structseq, capsule, cellobject (`cell_is_empty`
    always False), picklebufobject, interpolationobject, templateobject, fileobject,
    namespaceobject, moduleobject, classobject, funcobject, unicodectype,
    unicodeobject, bytes_methods, methodobject, descrobject, typeobject stubs —
    ~450+ lines of identity helpers (`union_is_empty(n) { return n == 0; }`).
    Move outside the import graph (reference corpus tree like `Objects/_lifted/`)
    or delete until wired.
2. **dictobject.jac:19-95** open-addressing probe section (~75 lines) unused —
    header admits it's "c2jac reference for a future native table". Quarantine.
3. **longobject.jac:23-260** digit-vector add/sub/compare machinery unreachable
    (ceval routes int compares through `PyObj.tp_richcompare`); reimplements
    bignum arithmetic on top of Jac's already-bignum host ints. Delete or quarantine.
4. **floatobject.jac:96-103** dead `float_eq_doubles`/`float_ne_doubles`.

### D. Corpus/gates integrity

1. **20 committed `_staging/*.c` scratch files** contradict `.gitignore:94-96` and
    get rmtree'd by lift scripts on next run → tracked-file churn. Untrack.
2. **`tools/sync_staged_to_lifted.py:59-66,107`** sidecar-zeroing makes part of the
    Tier-B density ratchet unauditable — staged counts silently reset to lifted ones.
3. **na_cliffs t7_gate.py + na_concat.py not wired to CI** despite "runs in CI"
    docstrings.

### E. Hygiene / scope (upstream PR cleanliness)

1. **Session artifacts committed at repo root**: CURRENT.md, FIXME.md,
    INTEGRATION_PLAN.md, PROGRESS.md, PR_SPLIT_PLAN.md, TASK.md, AUDIT-typefacts-infer_type.md,
    SKILL.md (+ AGENTS.md/CLAUDE.md additions). Keep out of the upstream PR.
2. **`.cursor/hooks.json` + `.cursor/hooks/notify-agent-complete.sh`** — personal
    editor tooling; remove from PR.
3. **Release-note fragments use issue numbers** (7145/7230/7353.*.md); CONTRIBUTING
    requires PR numbers. Rename when those land as PRs or drop fragments until then.
4. **`.gitignore` per-wave negation lines grow linearly; `.jacignore` has broad
    unqualified basenames** (e.g. `types.impl.jac`) that can over-ignore future files.
5. **Minor compiler-core nits to track** (details in compiler report):
    layout_pass.impl.jac:394 `resolve_ref` leaves `list[Foo]` type_tags unresolved in
    shared-registry mode; normalize_pass synthesized-token line interpolation is a
    post-hoc workaround (anchor positions should be set at token creation);
    parser.impl.jac:5090 wrong-kwarg clib() error cascades a second parse error;
    tools.impl.jac `_run_c_transform` ~135-line argparse clone.

### Positives worth keeping

- Error-propagation discipline (`is_error` checks) consistent across the runtime;
  no debug prints, no swallowed-error paths found in hot dispatch.
- `pyhash.jac` SipHash-13/PYTHONHASHSEED port matches CPython semantics exactly.
- vtable GEP-on-coerced-receiver fix, SHA256 exception-type-ids, doc_ir_gen identity
  check, pyast_load ctrl_loc, jir clib header-dep tracking — all root-cause fixes
  with tests. Good pattern.

---

## Adversarial-review findings (YoungViper — live log, append-only)

Status per item as of last update. Verified = I reproduced it myself; fixed = fix landed and I re-verified.

### Open

### Open

0. **[COMPILER][HIGH] Compiled-jac `del d[k]` on typed dicts pins the removed value.**
   Found while implementing native weakref (workaround 4fc98bc13). An ObjectAnchor
   gets cached in the removed object's **dict** via cached_property `__jac__`; the
   anchor is a strong root that gc.collect() cannot reach, so every object whose
   last reference dies through compiled-jac dict deletion leaks forever.
   Repro: ceval-interpreted `o = C(); del o` leaves o alive after exec returns;
   deleting the same ns entry from pure python frees it immediately (refcount).
   Affected: any compiled-jac `del self.items[...]` statement (dict subscript
   delete, set pop/discard, list index del) plus ceval's DELETE_NAME/GLOBAL.
   VM-side workaround: value-bearing delete sites routed through python-mode
   `_py_container_del` in ceval.jac/objects.jac - revert once the del lowering
   becomes refcount-clean. Owner: jac0 compiled lowering (unowned in mesh).

1. **[MED] User-defined descriptor protocol not invoked on attribute access.**
   A class attribute whose value defines `__get__` is returned RAW instead of
   bound: `C().attr` yields the Ten() instance rather than calling
   `__get__(obj, owner) -> 10`. Data descriptors (`__set__`) likewise ignored.
   Native `property` works because it is special-cased; user descriptors are not.
   Repro: class Ten with **get** returning 10; class C: attr = Ten(); C().attr.
   Fix direction: tp_getattro/attribute path must check class-dict values for
   **get**/**set** before returning (data-descr priority over instance dict).

2. **[LOW-MED] Exposed `__mro__` is not the C3 linearization.**
   `A.__mro__` == `(A,)` — missing `object`; diamond classes expose immediate
   bases only. Internal DISPATCH MRO is correct (diamond method resolution
   verified green), so this is the introspection surface only.
   Fix: expose the same linearized order dispatch uses, with object appended.

3. **[LEDGER, carried]** to_host wrapper gaps (PyNativeBuiltin/bound methods);
   weakref API coverage debt. Single-branch workflow: fix in-branch, no GitHub issues.

4. **[MED] User-class `__call__` not honored.** Calling an instance of a class
   defining `__call__` raises TypeError("object is not callable"); type(f).**call**
   is never consulted by the call path. Explicit f.**call**(x) presumably works.
   Repro: Adder(10)(5) -> should be 15.

5. **[MED] Iteration protocol ignores user dunders.** GET_ITER/FOR_ITER on a
   user object does NOT look up **iter**/**next**: list(g) raises
   TypeError("'NoneType' object is not iterable") even though g.**next**()
   works when invoked explicitly. Same family as #1/#4: dunder lookup exists
   for some protocols (**getitem**, **getattr**, **len**/**bool**, arithmetic,
   **init_subclass**) but not callable/iterator/descriptor.

6. **[CODEGEN-PARITY] three byte-parity gaps (from QuickBear's compiler
   differential lane; sentinels exist in their working tree).**
   a. CONST-POOL ORDERING: folded container consts interned eagerly at fold time;
      CPython interns late, after the implicit epilogue None -> structurally equal
      bytes, shifted const indices (`t = (1,2,3)`: ours LOAD_CONST 0 vs host 2).
      Highest blast radius; interacts with band-11 nested-code consts.
   b. CONSTANT-SET DISPLAYS: host emits BUILD_SET 0 + frozenset const +
      SET_UPDATE 1; we emit element-wise loads + BUILD_SET N. Verified against
      local CPython 3.14 by BrightTiger (intrinsic lowering applies to plain
      assignments, not just membership tests).
   c. BOOL-NOT IN JUMP CONTEXT: host folds `if not flag:` into inverted
      PJUMP_IF_FALSE; we emit UNARY_NOT + COPY + TO_BOOL + PJUMP_IF_TRUE.
   NOTE: all three are parity-only (semantics-neutral); they block codegen
   differential harnesses, not runtime correctness. Sentinel for (c) should
   include a user class whose **bool** has side effects (evaluation-count check).

7. **[MED] List slice ASSIGNMENT broken both paths.** `xs[::2] = [7, 8]`
    raises TypeError("list indices must be integers") — STORE_SUBSCRIPT does
    not accept PySlice. Direct xs.**setitem**(slice(0,4,2), [7,8]) returns
    None but silently does NOT mutate (mp_ass_subscript slice branch missing/
    no-op). Asymmetric: slice READ (xs[::2]) and slice DELETE (del xs[1:3])
    both work. Same silent-noop family as the old unbound-method bug.
    Repro: xs=[0,0,0,0]; xs[::2]=[7,8] -> expect [7,0,8,0].

8. **[HARNESS] `_l1_flatten_seq` corrupts setup containing try/except —
    can produce FALSE GREENS.** layer0_replay_harness.jac:110 expands ast.Try
    into its inner statements at statement scope, discarding the try/except
    wrapper: `try: f()\nexcept E as r: out.append(r)` becomes bare `f()` +
    hoisted handler lines referencing undefined r. Two failure modes:
    (a) honest-skip when host probe declines (NameError), silently losing ALL
    try-in-setup coverage — every exc-chaining case so far never ran;
    (b) WORSE: when the flattened sequence still executes (e.g.
    `try: x=risky() except: x=0` -> `x=risky(); x=0`), both interpreters run
    identical wrong code and the check PASSES — false conformance.
    Docstring's claim that "control flow stays in setup" is untrue for Try.
    Fix direction: keep the Try node intact in setup_src; lift ONLY
    self.assertX Expr nodes found inside as extra checks AND mark the method
    needs-capture (skip) since post-hoc expression eval can't see handler
    scope. Never rewrite control flow into sibling statements.

9. **[MED] `instance.__class__` AttributeError on user instances.**
    a.**class** -> AttributeError("**class**") for any user-class instance;
    works for natives ([].**class** == list). dir(a) lists **class**, so the
    surface claims it but getattr misses it. Breaks common idiom
    e.**class**.**name** on caught exceptions too. Retroactively explains the
    round-8 call-bisect failure attributed to **call**. Fix: PyUserObj getattr
    resolves **class** to its class object (and audit sibling identity dunders:
    **dict**, **module** on instances).

10. **[LOW] callable() says False for user classes.** callable(C) where C is
    a plain user class returns False (CPython: True — classes instantiate).
    callable(fn) works. Part of the type-slot family: tp_call presence isn't
    consulted for user types.

11. **[LOW-MED] Generator return value lost on manual next() exhaustion.**
    def g(): yield 1; return 99 — after consuming via next(), the terminal
    StopIteration has .value == None instead of 99. Asymmetric: yield from
    DOES forward the inner gen's return correctly (yieldfrom-return-value
    green), so the internal path carries it but the caller-facing
    StopIteration doesn't attach .value. Only affects explicit-iteration
    consumers (for loops ignore .value).

### Root-cause synthesis (all findings collapse into 4 families)

**A. No unified dunder dispatch** (items 1/4/5/12/13/15/17, +2 adjacent).
Protocol resolution was built per-feature instead of through one shared
type-MRO lookup: objects.jac has SIX separate tp_getattro impls; dunders work
exactly where someone hand-wired a path (**getitem**/**add**/**eq**) and fail
where nobody did (**call**/**iter**/descriptors/**getattr**/**class**).
CPython's tp_* slot tables exist precisely to prevent this. Fix = unify via
one MRO-walker core, two policy flavors (see GoldLion review thread).

**B. Asymmetric slot coverage / half-wired features** (items 8/10/14/18).
Each feature implemented against whichever test exposed one half first:
sort has key= but sorted/max/min don't; slice read+del work but assign
doesn't; gen return carried internally but StopIteration.value empty;
property getter/setter without deleter. Fix = spec-driven completeness pass
over builtin signatures and slot triples (get/set/del), not item patches.

**C. Guest-host bridge marshaling ad hoc** (item 16, item 7, to_host ledger).
Unknown shapes fall back to WRONG defaults (coro -> list) or raise where
CPython compares exactly (inf vs bigint). Fix = typed conversion table at the
boundary with explicit unknown-type policy.

**D. Harness blind spots** (item 11 + coverage-map mis-claim lesson).
Differential testing cannot see identical-wrong-on-both-sides; harness rewrites
control flow. Mitigation already in place: pin corpus + sentinel pre-runs.

Meta-root-cause: bottom-up conformance (make each observed test pass) instead
of top-down architecture (slot table + single lookup). Explains why ~60 green
domains coexist with these gaps: lifted-from-bytecode areas are solid,
hand-dispatched areas hole exactly where no test looked. STRATEGY: unify,
don't patch — individual fixes leave holes reopening under future features.

**PIN CORPUS FROZEN**: jac-py/tools/fuzz_corpus_pinned.json — 16 cases:
minimal repros for items 1/2/4/5/7/8/10/12/13/14 (red until fixed), descriptor
precedence + instance-dict-inverse sentinels (guard the sweep), and
healthy-behavior pins (exception chaining via nested-def) that must stay green.
Not wired into CI; run manually via _fuzz_smoke.jac. Delete _fuzz_smoke.jac +
_fuzz_introspect.jac before any upstream PR; the pin file itself should land.

1. **[MED] `__getattr__` fallback never implemented.** Proxy().zzz raises
    bare AttributeError('zzz') — type.**getattr** is never consulted on lookup
    failure. objects.jac has ZERO **getattr** references (grep-verified).
    Breaks lazy proxies/delegation idioms wholesale.
    CORRECTION: early coverage-map entry listed **getattr** green — that was
    WRONG (mis-attributed from an unharvested case). Coverage map corrected.

2. **[HIGH if async in scope] Coroutine/bridge integration broken.**
    (a) asyncio.run(vm_coro()) -> "An asyncio.Future, a coroutine or an
    awaitable is required": host event loop cannot recognize guest coroutines
    across the bridge. (b) type(coro_obj) returns PyHostProxy(val=list) —
    type() misreports coroutine objects as list (to_host wrapper gap family,
    cf. carried ledger item). hasattr(c,'send') True, so the object exists;
    identification/bridging is what fails.

3. **[MED] Exception class passed to **exit** lacks **name**.**
    with-protocol suppression itself works (return True suppresses, exit args
    flow), but reading et.**name** inside **exit** raises bare AttributeError
    ("**name**"). The raised-exception CLASS object crossing into user code is
    missing identity attrs — same family as item 12 (**class** synthesis).
    Repro: log.append(et.**name** if et else None) inside **exit**.

4. **[LOW-MED] property .deleter ignored.** del o.x on a property with
    @x.deleter raises AttributeError('x'); getter/setter both work (verified
    green separately). mp_del_subscript/del-attr path doesn't consult
    property fdel. Same asymmetry shape as slice-assign (item 10).

Note: module-level @class-decorators are UNTESTABLE by the layer1 harness
(module top-level code isn't replayed); function decorators in-method are
green. Class-decorator support needs pinning elsewhere.

Pattern note: user-class dunder support is piecemeal — consider one sweep that
routes ALL protocols through a common type-slot/dunder lookup instead of
per-protocol special cases.

1. **[LOW-MED] float('inf') compared with huge int raises.** `inf > 10 ** 400`
   errors on jacpython (likely OverflowError converting the int to float);
   CPython compares exactly and returns True — no conversion overflow allowed.

2. **[CODEGEN-PARITY] three byte-parity gaps (from QuickBear's compiler
   differential lane; sentinels exist in their working tree).**
   a. CONST-POOL ORDERING: folded container consts interned eagerly at fold time;
      CPython interns late, after the implicit epilogue None -> structurally equal
      bytes, shifted const indices (`t = (1,2,3)`: ours LOAD_CONST 0 vs host 2).
      Highest blast radius; interacts with band-11 nested-code consts.
   b. CONSTANT-SET DISPLAYS: host emits BUILD_SET 0 + frozenset const +
      SET_UPDATE 1; we emit element-wise loads + BUILD_SET N. Verified against
      local CPython 3.14 by BrightTiger (intrinsic lowering applies to plain
      assignments, not just membership tests).
   c. BOOL-NOT IN JUMP CONTEXT: host folds `if not flag:` into inverted
      PJUMP_IF_FALSE; we emit UNARY_NOT + COPY + TO_BOOL + PJUMP_IF_TRUE.
   NOTE: all three are parity-only (semantics-neutral); they block codegen
   differential harnesses, not runtime correctness. Sentinel for (c) should
   include a user class whose **bool** has side effects (evaluation-count check).

3. **[MED] List slice ASSIGNMENT broken both paths.** `xs[::2] = [7, 8]`
    raises TypeError("list indices must be integers") — STORE_SUBSCRIPT does
    not accept PySlice. Direct xs.**setitem**(slice(0,4,2), [7,8]) returns
    None but silently does NOT mutate (mp_ass_subscript slice branch missing/
    no-op). Asymmetric: slice READ (xs[::2]) and slice DELETE (del xs[1:3])
    both work. Same silent-noop family as the old unbound-method bug.
    Repro: xs=[0,0,0,0]; xs[::2]=[7,8] -> expect [7,0,8,0].

4. **[HARNESS] `_l1_flatten_seq` corrupts setup containing try/except —
    can produce FALSE GREENS.** layer0_replay_harness.jac:110 expands ast.Try
    into its inner statements at statement scope, discarding the try/except
    wrapper: `try: f()\nexcept E as r: out.append(r)` becomes bare `f()` +
    hoisted handler lines referencing undefined r. Two failure modes:
    (a) honest-skip when host probe declines (NameError), silently losing ALL
    try-in-setup coverage — every exc-chaining case so far never ran;
    (b) WORSE: when the flattened sequence still executes (e.g.
    `try: x=risky() except: x=0` -> `x=risky(); x=0`), both interpreters run
    identical wrong code and the check PASSES — false conformance.
    Docstring's claim that "control flow stays in setup" is untrue for Try.
    Fix direction: keep the Try node intact in setup_src; lift ONLY
    self.assertX Expr nodes found inside as extra checks AND mark the method
    needs-capture (skip) since post-hoc expression eval can't see handler
    scope. Never rewrite control flow into sibling statements.

5. **[MED] `instance.__class__` AttributeError on user instances.**
    a.**class** -> AttributeError("**class**") for any user-class instance;
    works for natives ([].**class** == list). dir(a) lists **class**, so the
    surface claims it but getattr misses it. Breaks common idiom
    e.**class**.**name** on caught exceptions too. Retroactively explains the
    round-8 call-bisect failure attributed to **call**. Fix: PyUserObj getattr
    resolves **class** to its class object (and audit sibling identity dunders:
    **dict**, **module** on instances).

6. **[LOW] callable() says False for user classes.** callable(C) where C is
    a plain user class returns False (CPython: True — classes instantiate).
    callable(fn) works. Part of the type-slot family: tp_call presence isn't
    consulted for user types.

7. **[LOW-MED] Generator return value lost on manual next() exhaustion.**
    def g(): yield 1; return 99 — after consuming via next(), the terminal
    StopIteration has .value == None instead of 99. Asymmetric: yield from
    DOES forward the inner gen's return correctly (yieldfrom-return-value
    green), so the internal path carries it but the caller-facing
    StopIteration doesn't attach .value. Only affects explicit-iteration
    consumers (for loops ignore .value).

### Root-cause synthesis (all findings collapse into 4 families)

**A. No unified dunder dispatch** (items 1/4/5/12/13/15/17, +2 adjacent).
Protocol resolution was built per-feature instead of through one shared
type-MRO lookup: objects.jac has SIX separate tp_getattro impls; dunders work
exactly where someone hand-wired a path (**getitem**/**add**/**eq**) and fail
where nobody did (**call**/**iter**/descriptors/**getattr**/**class**).
CPython's tp_* slot tables exist precisely to prevent this. Fix = unify via
one MRO-walker core, two policy flavors (see GoldLion review thread).

**B. Asymmetric slot coverage / half-wired features** (items 8/10/14/18).
Each feature implemented against whichever test exposed one half first:
sort has key= but sorted/max/min don't; slice read+del work but assign
doesn't; gen return carried internally but StopIteration.value empty;
property getter/setter without deleter. Fix = spec-driven completeness pass
over builtin signatures and slot triples (get/set/del), not item patches.

**C. Guest-host bridge marshaling ad hoc** (item 16, item 7, to_host ledger).
Unknown shapes fall back to WRONG defaults (coro -> list) or raise where
CPython compares exactly (inf vs bigint). Fix = typed conversion table at the
boundary with explicit unknown-type policy.

**D. Harness blind spots** (item 11 + coverage-map mis-claim lesson).
Differential testing cannot see identical-wrong-on-both-sides; harness rewrites
control flow. Mitigation already in place: pin corpus + sentinel pre-runs.

Meta-root-cause: bottom-up conformance (make each observed test pass) instead
of top-down architecture (slot table + single lookup). Explains why ~60 green
domains coexist with these gaps: lifted-from-bytecode areas are solid,
hand-dispatched areas hole exactly where no test looked. STRATEGY: unify,
don't patch — individual fixes leave holes reopening under future features.

**PIN CORPUS FROZEN**: jac-py/tools/fuzz_corpus_pinned.json — 16 cases:
minimal repros for items 1/2/4/5/7/8/10/12/13/14 (red until fixed), descriptor
precedence + instance-dict-inverse sentinels (guard the sweep), and
healthy-behavior pins (exception chaining via nested-def) that must stay green.
Not wired into CI; run manually via _fuzz_smoke.jac. Delete _fuzz_smoke.jac +
_fuzz_introspect.jac before any upstream PR; the pin file itself should land.

1. **[MED] `__getattr__` fallback never implemented.** Proxy().zzz raises
    bare AttributeError('zzz') — type.**getattr** is never consulted on lookup
    failure. objects.jac has ZERO **getattr** references (grep-verified).
    Breaks lazy proxies/delegation idioms wholesale.
    CORRECTION: early coverage-map entry listed **getattr** green — that was
    WRONG (mis-attributed from an unharvested case). Coverage map corrected.

2. **[HIGH if async in scope] Coroutine/bridge integration broken.**
    (a) asyncio.run(vm_coro()) -> "An asyncio.Future, a coroutine or an
    awaitable is required": host event loop cannot recognize guest coroutines
    across the bridge. (b) type(coro_obj) returns PyHostProxy(val=list) —
    type() misreports coroutine objects as list (to_host wrapper gap family,
    cf. carried ledger item). hasattr(c,'send') True, so the object exists;
    identification/bridging is what fails.

3. **[MED] Exception class passed to **exit** lacks **name**.**
    with-protocol suppression itself works (return True suppresses, exit args
    flow), but reading et.**name** inside **exit** raises bare AttributeError
    ("**name**"). The raised-exception CLASS object crossing into user code is
    missing identity attrs — same family as item 12 (**class** synthesis).
    Repro: log.append(et.**name** if et else None) inside **exit**.

4. **[LOW-MED] property .deleter ignored.** del o.x on a property with
    @x.deleter raises AttributeError('x'); getter/setter both work (verified
    green separately). mp_del_subscript/del-attr path doesn't consult
    property fdel. Same asymmetry shape as slice-assign (item 10).

Note: module-level @class-decorators are UNTESTABLE by the layer1 harness
(module top-level code isn't replayed); function decorators in-method are
green. Class-decorator support needs pinning elsewhere.

Pattern note: user-class dunder support is piecemeal — consider one sweep that
routes ALL protocols through a common type-slot/dunder lookup instead of
per-protocol special cases.

1. **[MED] sorted()/max()/min() silently ignore key=.** sorted(['bbb','a','cc'],
   key=len) -> ['a','bbb','cc'] (lexicographic, key dropped); max(same, key=len)
   -> 'cc' (should be 'bbb'). Silent wrong answers, same severity family as the
   unbound-method silent no-op. Note list.sort(key=) DOES work (ae82851a0), so
   the decorate-sort-undecorate logic exists but isn't wired into these builtins.
   Fix: forward key=/reverse= from sorted/max/min to the same machinery; also
   audit any other builtin accepting key= (filter/map fine, but check
   itertools-style helpers if lifted).

### Fixed & verified

- [a13ba6a06] repr() drained native iterators → py_repr '<iterator object>' pre-to_host;
  verified repr observational (next(it) after repr yields 1). Also py_type_of host-type
  names for native wrappers (type(len) == 'builtin_function_or_method'); capsule
  abs() workaround removed; HARNESS A strict setup errors count ERRORED.
- [a13ba6a06] HARNESS C residual: _dedent_segment strips exactly base_col per
  continuation line; try/except/else setups replay green end-to-end (exc-else verified).
- [d5235d1d7] unbound builtin-method silent no-op — list.append/dict.get route to
  native wrappers; PyIter.tp_iter + to_host drain for host consumers.
- `list.sort()` missing entirely (silent no-op via host-copy mutation) — ae82851a0;
  my 99-case stateful corpus went 77/99 → 99/99 post-fix; stability-under-key verified.

- `list.sort()` missing entirely (silent no-op via host-copy mutation) — ae82851a0;
  my 99-case stateful corpus went 77/99 → 99/99 post-fix; stability-under-key verified.
- Undefined name raised AttributeError("module 'builtins' has no attribute") instead
  of NameError — ae82851a0, verified via assertRaises(NameError).
- Generator re-entrancy unguarded (would recurse run_frame on live frame) — 62e7018d1;
  bypass sweep confirmed all resume/throw paths funnel through guarded entries.
- HARNESS: 25/107 real probe methods never replayed — all "skips" were indentation-
  corruption artifacts from get_source_segment + single global dedent — 1d823f5d6;
  independently re-verified 107/107 passed / 0 skipped across all 44 stems.
- PyHostProxy eq/hash inconsistency — 1d823f5d6 option-2 implementation reviewed;
  identity fast-path + host-eq defer + error propagation all correct.

### Fuzz coverage map (all differential vs CPython, green)

richcompare chains/reflected priority · dict key collapse/order · bigint hash parity ·
floor/mod signs · gen yield/close/throw/yield-from/StopIteration→RuntimeError/reentrancy ·
exception hierarchy/tuple-match/nested-finally/return-in-finally/reraise/NameError ·
comprehension scoping (no-leak)/dict/set-comp/genexpr · f-strings/%-format/format() ·
with enter/exit/suppression · operator overloads (**add**/**radd**/**eq**/**hash**/
**len**/**bool**/**repr** fallback) · slice semantics · str methods ·
loop for/while-else + break · set algebra (- ^ <= <) · dict setdefault/update(kw) ·
bytes slice/concat/int-list · any/all over generators · enumerate/zip ·
closures + nonlocal counters · *args/**kwargs/keyword-only/default-eval-once ·
star-unpacking (a,*b, c) · dict views as sets · unbound builtin dispatch ·
chained comparisons · subscript augmented assignment · pow-mod/negative bitops/
~ · round/abs bigint · true-div semantics · nan equality · int() bases/whitespace ·
exception type fidelity (IndexError/KeyError/AttributeError) · math module attrs ·
unicode escapes/ord/chr · container repr nesting · ternary/boolop short-circuit ·
utf-8/ascii/latin-1 codecs · dict get/pop defaults/fromkeys · map/filter(None) ·
zip-shortest · list count/index/remove · chained/multi-target assignment ·
tuple swap + immutable augassign · global stmt · complex numbers (real/imag/
abs/conjugate/pow) · numeric-tower eq/hash/set-dedup · generator send/close/
throw/yield-from nesting · self-referential containers · format_map ·
nested/dict/set comprehensions · divmod negatives + banker's rounding ·
int.to_bytes/from_bytes · str.maketrans/translate/expandtabs/ljust/rjust ·
sum(start) incl. list concat · bool-as-int indexing · bytes.maketrans+delete.

Known harness limits when writing new probes: asserts must be direct statements of a
`test_*` method (no nesting inside try/with); avoid literal `self` tokens outside the
assert calls; assert args must be interpreter-independent or folded intra-expression;
host-baked literal expected values are stronger than self-comparisons.

Infra: `/tmp/gen_fuzz.py`, `/tmp/gen_fuzz2.py` (corpus generators),
`jac-py/jacpython/_fuzz_smoke.jac` (driver, reads /tmp/fuzz_cases.json),
`jac-py/jacpython/_fuzz_introspect.jac` (direct namespace inspection).
Run: `JACPYTHON_CPYTHON=python3 .venv/bin/jac run jac-py/jacpython/_fuzz_smoke.jac`
(both .jac files are temp — delete before any upstream PR).
