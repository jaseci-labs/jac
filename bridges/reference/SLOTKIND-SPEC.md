# SlotKind Marshal Abstraction -- Design Spec (FFI-LANES Phase 0.5.1)

Track A audit deliverable. Source of the future
`jac/jaclang/compiler/rust_bridge/_marshal.jac`.

Audited generators (both READ-ONLY here):

- **na**  = `jac/jaclang/compiler/rust_bridge/_synth.jac` (na/LLVM source emitter)
- **cty** = `jac/jaclang/compiler/rust_bridge/_ctypes_codegen.jac` (CPython ctypes emitter)
- Tag constants + decoders: `jac/jaclang/compiler/rust_bridge/_blob.jac`
- na container AST resolution: `.../passes/native/na_ir_gen_pass.impl/types.impl.jac`

The two generators today **share zero code** and each re-derive tag→wire lowering
by hand. They have drifted. This spec catalogs every case, proposes a `SlotKind`
enum + `classify()` that becomes the single source of truth, and flags the rows
where unifying will *change* one generator's behavior (golden-test targets).

---

## 1. Tag decode reference (`_blob.jac`)

| Const | Value | Notes |
|---|---|---|
| `TAG_VOID` | `0xFFFFFFFF` | `_blob.jac:5` |
| `TAG_BOOL` | `1` | `:6` |
| `TAG_INT`  | `2` | signed i64 |
| `TAG_UINT` | `3` | unsigned u64 |
| `TAG_STR`  | `4` | |
| `TAG_FN`   | `5` | callback param only |
| `TAG_REF_BIT` | `0x80000000` | opaque handle; low bits = type index |
| `TAG_OPT_BIT` | `0x40000000` | orthogonal modifier (`Option<T>`) |
| `TAG_MAP_BIT` | `0x20000000` | `HashMap` → dict |
| `TAG_LIST_BIT`| `0x10000000` | `Vec` → list |

Decoders (`_blob.jac:28-66`) -- note the **asymmetry that classify() must honor**:

- `tag_base(t)  = t & ~TAG_OPT_BIT`   -- strips **only** OPT (ref/map/list bits survive).
- `tag_is_opt(t)= t & TAG_OPT_BIT`
- `tag_is_ref(t)= (tag_base(t) & TAG_REF_BIT) and base != TAG_VOID`
- `tag_ref_index(t) = tag_base(t) & ~TAG_REF_BIT`
- `tag_is_map(t)  = t & TAG_MAP_BIT`;  `tag_map_value(t) = t & ~TAG_MAP_BIT`
- `tag_is_list(t) = t & TAG_LIST_BIT`; `tag_list_value(t)= t & ~TAG_LIST_BIT`

Map/list bits are checked on the **raw** tag; map/list value tags strip only the
container bit (OPT can survive on the value -- but no producer emits that today).

---

## 2. PARAM (in-slot) marshalling -- full case table

na has three param call sites that must agree: `_shim_decl` (the `import from
"<so>"` extern signature), `_method_body` call-args, `_ctor_body` call-args.
cty has two: `_wire` (`argtypes`), `_call` (arg packing).

| Tag / predicate | na `_shim_decl` (:166-205) | na body arg (`_method_body` :337-353 / `_ctor_body` :434-451) | cty `_wire` argtypes (:197-207) | cty `_call` pack (:317-337) | Drift |
|---|---|---|---|---|---|
| self handle (method, `self_type!=VOID`) | `handle: int` (:168) | `self.__handle` (:336) | `c_uint64` (:193) | `self_h` (:313) | -- |
| `TAG_STR` | `pn: str`, `pn_len: int` (:174) | `pn, strlen(pn)` (:340) | `c_char_p, c_uint32` (:199) | `_encode(v)` → `(enc, c_uint32(n))` (:321) | -- |
| `TAG_BOOL` | `pn: int` (:176) | `(pn and 1 or 0)` (:343) | `c_uint8` (:201) | `c_uint8(int(bool(v)))` (:323) | -- |
| `TAG_INT` | `pn: int` (:176) | `pn` (:345) | `c_uint64` (else, :205) | `c_uint64(int(v)&MASK)` (:325) | -- |
| `TAG_UINT` | `pn: int` (:176) | `pn` (:345) | `c_uint64` (else, :205) | `c_uint64(int(v)&MASK)` (:325) | -- |
| `tag_is_ref` (opaque handle) | `pn: int` (:179) | `pn.__handle` (:347) | `c_uint64` (else, :205) | **`c_uint64(int(v))`** (else, :335) | **DRIFT-P1** |
| `TAG_FN` (callback) | `pn: int` (:180) | `pn` + set `_bridged_callback` (:349) | `c_uint64` (:203) | trampoline→`_JacCallback`→`addressof(rec)`, keepalive (:327-333) | **DRIFT-P2** |
| anything else | `return None` → **skip fn** (:182) | `return None` → **skip fn** (:351) | `c_uint64` (else, :205) | `c_uint64(int(v))` (else, :335) | **DRIFT-P3** |

**DRIFT-P1 (opaque-ref param):** na passes the wrapper's `.__handle`; cty's `_call`
has **no `tag_is_ref` arm** and falls to the `else` branch `c_uint64(int(v))`,
calling `int()` on a wrapper stub that defines no `__int__` → runtime `TypeError`.
cty is effectively broken for opaque-handle *parameters*; na is correct. Unifying
onto one `OpaqueRef` in-slot lowering fixes cty (behavior change -- needs a golden
test with a method that takes another opaque handle).

**DRIFT-P2 (callback param):** ABI matches (`c_uint64` address of a `_JacCallback`
record) but na only *forwards the int* -- na has no trampoline/closure codegen yet
(callback vertical is na-gated per M6). The shared layer should classify both as
`Callback` and let each backend supply its own lowering (cty: build trampoline;
na: currently gated/forward-only).

**DRIFT-P3 (unbridgeable param):** na **rejects** the fn (`_shim_decl`/body return
`None` → `render()` records a `Skip`, :508). cty never validates param tags -- the
`else` accepts *any* tag as `c_uint64`. So cty will silently attempt to bridge a
fn na drops. classify() must expose an explicit "unbridgeable → None" outcome and
both generators must consult it (behavior change for cty).

---

## 3. RETURN (out-slot) marshalling -- full case table

na return sites: `_shim_decl` out-slot (:186-201), `_method_body` decode
(:360-427), `_ret_ann` (:726-747). cty: `_wire` restype/out-slot (:209-220),
`_call` decode (:344-417).

| Tag / predicate | na `_shim_decl` out-slot | na `_method_body` decode | cty `_wire` out-slot | cty `_call` decode | Drift |
|---|---|---|---|---|---|
| `tag_is_map` | `out_buf: bytes` (:187) | `_na_decode_container` (:392, :292-332) | `POINTER(_JacBuf)` (:211) | `_decode_map` (:372-376) | see DRIFT-R4 (opt) |
| `tag_is_list` | `out_buf: bytes` (:187) | `_na_decode_container` (:392) | `POINTER(_JacBuf)` (:211) | `_decode_list` (:377-381) | see DRIFT-R4 |
| `tag_is_ref` | `out_handle: bytes` (:190) | **requires `ref_index in adoptable` else `None`** (:363-365); returns `target(rh)`, opt→`None` (:394-402) | `POINTER(c_uint64)` (else, :217) | returns stub, opt→`None`, unknown class→raw int (:404-417) | **DRIFT-R1** |
| `TAG_BOOL` (`ret==TAG_BOOL` exact / `base==BOOL`) | `out_bool: bytes` (:189, base) | `out_b`; `!=0` -- **exact `fd.ret==TAG_BOOL`** (:369) | `POINTER(c_uint8)` (base, :213) | `bool(out_b.value)` -- **`base_ret==BOOL`** (:385) | **DRIFT-R2/R4** |
| `TAG_STR` (`base==TAG_STR`) | `out_buf: bytes` (:192, base) | `out_buf`; str-from-raw+`free_buf`; opt→`None` else `""` (:372, :405-419) | `POINTER(_JacBuf)` (base, :215) | opt&ptr==0→`None`; else decode+`free_buf` (:388-395) | -- (both honor opt) |
| `TAG_INT` (`ret==TAG_INT` exact) | `out_int: bytes` (:194, base) | `out_int`; signed adjust (:376, :419-424) | `POINTER(c_uint64)` (else, :217) | `out_h.value` signed adjust -- `base_ret==INT` (:396) | **DRIFT-R4** |
| `TAG_UINT` (`ret==TAG_UINT` exact) | `out_int: bytes` (:195, base) | `out_int` raw u64 (:376, :425-427) | `POINTER(c_uint64)` (else, :217) | `out_h.value` -- `base_ret==UINT` (:400) | **DRIFT-R4** |
| `TAG_VOID` | (no out-slot) `pass` (:196) | (no decode, returns nothing) | (no out-slot) | `return None` (:382) | -- |
| `tag_is_opt` unmatched above | `return None` → skip (implicit) | `return None` → **skip fn** (:379) | (via base) decodes ignoring None | (via base) decodes ignoring None | **DRIFT-R4** |
| anything else | `return None` → skip (:199) | `return None` → skip (:381) | -- (no `else` reject) | falls through to ref path (:404) | **DRIFT-R3** |
| always (trailing) | `out_err: bytes` (:202) | -- | `POINTER(c_uint64)` out_e (:220) | `byref(out_e)` (:359) | -- |

**DRIFT-R1 (opaque-ref return + adoptable gate):** na **only** bridges a
ref-returning method when `tag_ref_index(ret) in self.adoptable` -- i.e. the
returned opaque type has no ctor of its own (na "adopt-ctor signature clash",
skip reason at `_synth.jac:511`, gate at `:363-365`). cty has **no such gate**:
`_make_class` binds every method and `_call` returns a stub for any ref
(`:404-417`), and if the class is unknown it returns the **raw int handle**
(`:409-411`) -- a case na never produces. **cty bridges ref-returning methods na
silently skips.** This is the single largest coverage divergence. Unifying must
decide: does the shared layer expose `adoptable` as a backend capability flag
(na keeps skipping) or does na gain adopt-return support? Either way cty's
raw-int-fallback (`classes.get→None`) has no na analog.

**DRIFT-R2 (exact-tag vs base-tag inconsistency -- *within na itself*):**
`_method_body` matches BOOL/INT/UINT with **exact** equality `fd.ret==TAG_BOOL`
(:369, :376), but `_shim_decl` (:186 `ret=tag_base`) and `_ret_ann`
(:733 `tag_base==TAG_BOOL`) match on **base**. So for `Option<bool>`/`Option<int>`,
na's shim-decl and return-annotation accept it while its body **rejects** it
(falls to :379 `tag_is_opt → None`). Net effect: the whole fn is skipped (render
requires both non-None, :508), but the three na sites disagree on the *reason*.
classify() must pick ONE rule (recommend: classify on `tag_base`, carry `is_opt`
as a flag) so all sites agree.

**DRIFT-R3 (unbridgeable return):** na explicitly rejects (`return None`, :381,
:199). cty `_wire`/`_call` have no reject arm -- an unexpected return tag falls
through `_wire`'s `else` (:216 `POINTER(c_uint64)`) and `_call`'s final ref path
(:404), mis-decoding it as an opaque handle. classify() needs an explicit
`Unbridgeable` outcome consulted by both.

**DRIFT-R4 (Option<T> for non-str/non-ref):** na handles `Option` **only** for
`Str` (:408-412) and `OpaqueRef` (:397-401). For `Option<bool/int/uint/map/list>`
na's body falls to `:379 tag_is_opt → None` → **skips the fn**. cty strips OPT via
`base_ret = tag_base` and decodes the payload **ignoring None semantics**
(no null representation for bool/int/uint; map/list never null-checked beyond the
`ptr==0 → b""` guard at :373/:378). So cty *silently returns a non-None value*
where na refuses to bridge. Unifying (opt as a first-class modifier on every
SlotKind) changes behavior on **both** sides -- highest-value golden-test target.

---

## 4. Container element read (map/list value) -- sub-table

na `_na_read_value` (`_synth.jac:263-289`) vs cty `_read_value`
(`_ctypes_codegen.jac:252-272`). Wire format is identical: `<I` count prefix, then
per-entry (map: `<I klen` + key bytes) + value.

| value tag | na read (:263-289) | cty read (:252-272) | Drift |
|---|---|---|---|
| `TAG_STR` | `base==TAG_STR`: `<I` len + `__jac_str_from_raw` (:266) | `vtag==TAG_STR`: `<I` len + decode (:253) | base vs exact (benign) |
| `TAG_BOOL`| `base==TAG_BOOL`: `<B != 0` (:273) | `vtag==TAG_BOOL`: `bool(b)` (:258) | base vs exact (benign) |
| `TAG_INT` | `vtag==TAG_INT`: `<q` (native signed) (:278) | else `<Q` + manual signed adjust (:262-268) | equivalent |
| else/`TAG_UINT` | `<Q` (:283) | `<Q` raw (:269) | equivalent |

na value-type annotation `_na_val_type` (:716-724) and `_ret_ann` map/list
(:726-732) collapse every non-str/non-bool value to `int`. Only Str/Bool/Int/Uint
values exist today; **nested containers-of-containers and opaque values are
unsupported on both sides** (no ref/map/list arm in either value reader). classify()
for a *value* tag should therefore reuse the scalar variants only.

na container decode is gated by `_bridged_str_method=True` (:293) which pulls in
the `free_buf` extern (:572); cty always has `free_buf` wired (:83). Not a wire
drift but a symbol-emission dependency the shared layer should centralize.

---

## 5. Status / error / exception dispatch -- sub-table

| status | na (`_drain_and_raise` :231-261) | cty (`_call` :363-370) | Drift |
|---|---|---|---|
| `st==0` | success path | success path | -- |
| `st==1` (Jac `Result::Err`) | read via `error_msg_sym` (or `panic_msg_sym` fallback), drop, **`raise ValueError`** (:251) | `drain_err(out_e, fd.throws)`, **`raise err_cls(fd.throws)(msg)`** -- the *bridge-declared* exception type (:363-365) | **DRIFT-S1** |
| `st!=0` (panic / `catch_unwind`) | read via `panic_msg_sym`, drop, **`raise RuntimeError`** (:258) | `drain_panic`, **`raise rt.PanicError`** (a synthesized `Exception` subclass, :369) | **DRIFT-S1** |
| `st==3` (callback threw) | n/a (na callbacks gated) | trampoline returns `3` (:245); surfaces as panic path | **DRIFT-S2** |

**DRIFT-S1 (exception class):** na raises **builtin** `ValueError`/`RuntimeError`
and ignores `fd.throws` entirely (single `error_msg_sym` chosen at ctor time,
:146-155). cty raises the **named per-type** error class selected by `fd.throws`
(`err_cls` :183-185, :364) and a distinct `PanicError` type. Callers catching a
specific bridge error type get different behavior across backends. The shared
layer should own the status→exception policy and the `STATUS_OK/ERR/PANIC/CB_ERR`
constants (currently magic numbers in both files).

**DRIFT-S2:** callback-error status `3` is defined only in cty's trampoline; na has
no callback codegen. Fold the status constants into `_marshal` so na inherits the
value when its callback vertical lands.

---

## 6. Symbol-name constructors & misc drift

All format-string'd independently; home them in `_marshal`:

| symbol | na | cty |
|---|---|---|
| `free_buf`   | `f"jac_{mod}_free_buf"` (:156) | `f"jac_{mod}_free_buf"` (:83) |
| `make_buf`   | `f"jac_{mod}_make_buf"` (:157) | `f"jac_{mod}_make_buf"` (:88) |
| `panic_message` | `f"jac_{mod}_panic_message"` (:159) | `:95` |
| `panic_drop` | `f"jac_{mod}_panic_drop"` (:160) | `:101` |
| `bridge init` | **not emitted / not called** | `f"jac_bridge_init_{mod}"` called (:529-537) | **DRIFT-M1** |

**DRIFT-M1:** cty calls `jac_bridge_init_<mod>` at load (best-effort, swallows
`AttributeError`); na **never** calls it. If any bridge relies on init side-effects
(global allocator install, lazy statics), the na path skips it. Out of strict
marshal scope but must be tracked when unifying loaders.

---

## 7. Proposed `SlotKind` enum

Minimal variant set covering every case in §2–§5. `Opt` is **not** a variant -- it
is an orthogonal `is_opt: bool` modifier carried on the `Slot`, resolving DRIFT-R2
and DRIFT-R4 by construction.

```jac
enum SlotKind {
    Str,          # TAG_STR
    Bool,         # TAG_BOOL
    Int,          # TAG_INT   (signed i64)
    Uint,         # TAG_UINT  (unsigned u64)
    Void,         # TAG_VOID  (return only)
    OpaqueRef,    # tag_is_ref -> carries ref_index
    Callback,     # TAG_FN    (param only)
    Map,          # tag_is_map  -> carries value SlotKind (scalar)
    List,         # tag_is_list -> carries value SlotKind (scalar)
    Unbridgeable  # explicit reject outcome (replaces scattered `return None`)
}
```

Companion `Slot` record (per the plan's `obj Slot`):

```jac
obj Slot {
    has kind: SlotKind;
    has is_opt: bool = False;   # TAG_OPT_BIT modifier
    has ref_index: int = -1;    # OpaqueRef only
    has value: SlotKind | None = None;  # Map/List element (scalar variant)
    has name: str = "";         # spliced (already reserved-word mangled) ident
}
```

### Per-variant lowering shapes

| SlotKind | selecting predicate | na in-slot (param) | na out-slot (return) | cty in (`_wire`/`_call`) | cty out (`_wire`/`_call`) |
|---|---|---|---|---|---|
| `Str` | `tag_base==TAG_STR` | `pn:str`,`pn_len:int` / `pn,strlen(pn)` | `out_buf:bytes` / `<QII` + str-from-raw + free_buf (+opt→None) | `c_char_p,c_uint32` / `_encode` | `POINTER(_JacBuf)` / string_at+free (+opt→None) |
| `Bool` | `tag_base==TAG_BOOL` | `pn:int` / `(pn and 1 or 0)` | `out_bool:bytes` / `<B !=0` (+opt) | `c_uint8` / `c_uint8(int(bool))` | `POINTER(c_uint8)` / `bool(v)` (+opt) |
| `Int` | `tag_base==TAG_INT` | `pn:int` / `pn` | `out_int:bytes` / `<Q` signed-adjust (+opt) | `c_uint64` / masked | `POINTER(c_uint64)` / signed-adjust (+opt) |
| `Uint`| `tag_base==TAG_UINT`| `pn:int` / `pn` | `out_int:bytes` / `<Q` raw (+opt) | `c_uint64` / masked | `POINTER(c_uint64)` / raw (+opt) |
| `Void`| `tag_base==TAG_VOID`| -- | (no slot) / no decode | -- | (no slot) / `None` |
| `OpaqueRef` | `tag_is_ref` | `pn:int` / `pn.__handle` | `out_handle:bytes` / `target(rh)` (+opt→None); **+adoptable gate (na only)** | `c_uint64` / **`v.__handle`** (FIX P1) | `POINTER(c_uint64)` / stub (+opt→None) |
| `Callback`  | `tag_base==TAG_FN` | `pn:int` / `pn` (na gated) | n/a | `c_uint64` / trampoline+`_JacCallback` | n/a |
| `Map` | `tag_is_map` | n/a | `out_buf:bytes` / `_na_decode_container` | n/a | `POINTER(_JacBuf)` / `_decode_map` |
| `List`| `tag_is_list`| n/a | `out_buf:bytes` / `_na_decode_container` | n/a | `POINTER(_JacBuf)` / `_decode_list` |
| `Unbridgeable` | none of the above | **skip fn** (record `Skip`) | **skip fn** | must reject (today: silently mis-lowers) | must reject |
| trailing `out_err` | always | `out_err:bytes` | | `POINTER(c_uint64)` | |

Note `OpaqueRef` in the **cty in-slot** column is the DRIFT-P1 fix: the shared
lowering must extract `.__handle`/`._handle` for ref params, which `_call` does
not do today.

---

## 8. `classify(tag) -> Slot` decision table (single source of truth)

Ordered; **first match wins**. This ordering reproduces both generators' effective
behavior while removing the exact-vs-base inconsistencies (DRIFT-R2).

```
def classify(tag: int) -> Slot:
    opt = tag_is_opt(tag)                       # orthogonal modifier
    if tag_is_map(tag):                         # 0x20000000 on raw tag
        return Slot(Map,  is_opt=opt, value=classify_scalar(tag_map_value(tag)))
    if tag_is_list(tag):                        # 0x10000000 on raw tag
        return Slot(List, is_opt=opt, value=classify_scalar(tag_list_value(tag)))
    if tag_is_ref(tag):                         # base & 0x80000000, base != VOID
        return Slot(OpaqueRef, is_opt=opt, ref_index=tag_ref_index(tag))
    base = tag_base(tag)                         # strips OPT only
    match base:
        TAG_STR  -> Slot(Str,  is_opt=opt)
        TAG_BOOL -> Slot(Bool, is_opt=opt)
        TAG_INT  -> Slot(Int,  is_opt=opt)
        TAG_UINT -> Slot(Uint, is_opt=opt)
        TAG_FN   -> Slot(Callback, is_opt=opt)   # param context only
        TAG_VOID -> Slot(Void)
        _        -> Slot(Unbridgeable)
```

`classify_scalar` is `classify` restricted to `{Str,Bool,Int,Uint}` (rejects
container/ref/fn values -- matches §4, where both value readers only handle
scalars). Precedence rationale: map/list bits and the ref bit are mutually
exclusive in the encoder, but map/list are tested on the **raw** tag while ref is
tested on `tag_base`, so classify must test container bits **before** decoding
`base` (mirrors na `_method_body` order :360→363 and cty `_call` order :349→404).

`lower_signature(fd) -> list[Slot]` then walks:
`[self? ] + [classify(p.tag) for p in params] + [return-out from classify(fd.ret)]

- [OUT_ERR]`, with`Unbridgeable` anywhere → the whole fn is skipped (unifies
na's per-arm `return None`).

---

## 9. Drift risks -- behavior *changes* on port (golden-test before 0.5.2/0.5.3)

Ranked by blast radius. Each needs a golden test capturing **current** output of
BOTH generators before the shared layer replaces them.

1. **DRIFT-R4 -- `Option<bool|int|uint|map|list>`.** na *skips* the fn; cty *silently
   returns a non-None value* (strips OPT via `tag_base`, no null path). Unifying opt
   as a first-class modifier changes BOTH sides. Highest risk: pick the semantics
   deliberately (recommend: bridge it, with a real null representation) and pin with
   a golden. *Test:* a method returning `Option<i64>` and `Option<bool>`.

2. **DRIFT-R1 -- opaque-ref return, non-adoptable + unknown-class fallback.** cty
   bridges ref-returning methods na skips (`adoptable` gate `_synth.jac:363-365`,
   skip reason :511) and has a raw-int fallback (`classes.get→None`, :409-411) with
   no na analog. Deciding the shared policy will change na's coverage (it starts or
   keeps skipping) and possibly remove cty's raw-int path. *Test:* method returning
   an opaque whose type also has a ctor; method returning an opaque of an
   unregistered index.

3. **DRIFT-P1 -- opaque-ref *parameter* on cty.** cty's `_call` has no ref arm →
   `int(wrapper)` `TypeError` today (latent bug). The shared `OpaqueRef` in-slot
   makes cty extract `.__handle` -- a behavior fix, so a *new* passing test rather
   than a regression pin. *Test:* method taking another opaque handle as an arg.

4. **DRIFT-S1 -- exception class.** na raises builtin `ValueError`/`RuntimeError`
   ignoring `fd.throws`; cty raises per-type `err_cls(fd.throws)` / `PanicError`.
   Homing status→exception policy in `_marshal` forces a single choice; whichever
   loses changes caller-visible `except` behavior. *Test:* a fn whose `Result::Err`
   is a named `#[jac_error]` type, asserted on the raised class from both loaders.

5. **DRIFT-P3 / DRIFT-R3 -- unbridgeable param/return silently accepted by cty.**
   cty has no reject arm; the `else`/fall-through mis-lowers as `c_uint64`/opaque.
   Adding the explicit `Unbridgeable` outcome makes cty *start skipping* fns it
   currently emits (possibly-broken) bindings for. *Test:* a fn with a param tag
   outside `{str,bool,int,uint,ref,fn}` -- assert both now skip identically.

6. **DRIFT-R2 -- na internal exact-vs-base inconsistency.** `_method_body` uses
   exact `fd.ret==TAG_BOOL/INT/UINT`; `_shim_decl`/`_ret_ann` use `tag_base`.
   classify() standardizes on base+opt-flag; confirm no currently-bridged fn
   changes skip/emit status. *Test:* differential re-run of the existing na
   conformance corpus -- output must be byte-identical for every non-opt scalar
   return (regression pin, not a behavior change).

7. **DRIFT-M1 -- na never calls `jac_bridge_init_<mod>`.** Out of strict marshal
   scope but surfaced by the symbol-constructor consolidation; track separately so
   the na loader gains the init call if any reference crate depends on it.

Lower-severity / benign (pin but not expected to move): DRIFT-P2 (callback ABI
matches; na forward-only, gated), §4 base-vs-exact value reads (equivalent),
`_bridged_str_method`/`free_buf` symbol-emission gating (centralize, no wire change).
