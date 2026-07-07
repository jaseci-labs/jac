# Rust bridge type model v2: unified, recursive ABI type system

Status: PLAN (pre-implementation). Supersedes the ad hoc per-shape additions that
produced TAG_INT / TAG_MAP_BIT / TAG_LIST_BIT in ABI v1.

Decisions locked:
- Type vocabulary follows the WIT / Component Model value types (record, variant,
  option, result, list, tuple, own/borrow handle). We borrow the semantics, not
  the wasm canonical lowering.
- Metadata blob AND runtime values are encoded with serde + postcard. The Rust
  encode/decode half is derived, not hand-written. Jac implements one postcard
  reader used for both the metadata and every value.
- Clean cutover to ABI v2. All seeds are in-tree and rebuilt from source, so v1 is
  deleted outright: no dual-parse, no manual offset layout, no compat layer.

## Why this exists

The list of "FFI shortcomings" (no floats, no bytes, no nullable scalars, no
nested containers, no collection params, no struct/enum by value, no real
callback signatures) is not seven independent features. Every one is blocked by
the same root cause: the boundary type is a single `u32` bitfield, and each new
shape was carved out of a spare high bit.

Current v1 encoding (jac-bridge-schema):

```
BOOL=1 INT=2 UINT=3 STR=4 FN=5 VOID=0xFFFFFFFF
REF_BIT =0x80000000  |  opaque type index
OPT_BIT =0x40000000  |  inner tag
MAP_BIT =0x20000000  |  value tag
LIST_BIT=0x10000000  |  element tag
```

Structural dead ends:

1. No nesting. `list[list[int]]` = `LIST_BIT | (LIST_BIT | INT)`, but ORing the
   same bit twice collapses. `map[str, list[int]]`, `Option<Vec<T>>`,
   `list[tuple]` are all unrepresentable.
2. Containers are return only. There is no MAP / LIST decode on the param side.
3. No room for composites. A struct or enum needs a field/variant list, with
   nowhere to hang it off a scalar u32.
4. Callbacks are a fixed shape. TAG_FN hardcodes `fn(&str) -> String`.
5. Four hand written type readers. The macro (`Tag`), the binder (`ScalarType` /
   `BridgeReturn`), the CPython loader, and the native synth each re-derive
   meaning from the u32 inline. Every new shape is edited into all four by hand:
   the "one-off cases" the mission calls out.

## The model: a WIT-shaped type table of recursive nodes

Replace the inline `u32` tag with a `TypeId`: a u32 index into a per-module
**type table**, an append-only array of `TypeNode`s carried in the blob. A param,
a return, a struct field, a map key/value, and a callback signature slot all
carry a `TypeId`. Composite nodes reference children by `TypeId`, so the model is
recursive with no depth limit and no bit exhaustion.

### TypeNode kinds (WIT value-type vocabulary)

```
Primitives (no operands):
  Void Bool Char Str Bytes
  S8 S16 S32 S64 Ssize          (signed,   width kept in the KIND)
  U8 U16 U32 U64 Usize          (unsigned, width kept in the KIND)
  F32 F64

Composites (operands are TypeId indices):
  Handle(type_desc_index)              WIT own/borrow -> opaque bridge handle
  Option(inner: TypeId)                any inner (presence flag on the wire)
  Result(ok: TypeId, err: TypeId)      generalizes the current Result path
  List(elem: TypeId)                   -> Jac list, recursive
  Map(key: TypeId, val: TypeId)        -> Jac dict, recursive
  Tuple(elems: [TypeId])               -> Jac tuple, heterogeneous
  Record(record_desc_index)            WIT record -> struct by value
  Variant(variant_desc_index)          WIT variant -> enum, tagged union
  Func(fn_sig_index)                   callback with a real signature
```

Integer width lives in the KIND (S32 vs S64 are distinct nodes); the wire slot is
still one postcard varint, but the model preserves width so the binder can
re-declare the exact crate signature and the loader can range-check. On the Jac
side every integer still surfaces as `int`.

### Metadata blob = one serde struct, postcard-encoded

The current 56-byte header plus manual `put_u32` / StrRef offset math is deleted.
The metadata is a single Rust type deriving `Serialize`:

```rust
struct BridgeMeta {
    magic: [u8;8], abi_version: u32, module: String,
    types:   Vec<TypeDesc>,     // opaque + error handle types, with drop syms
    type_table: Vec<TypeNode>,  // the recursive nodes; everything else indexes here
    records: Vec<RecordDesc>,   // ordered fields: [(name, TypeId)]
    variants: Vec<VariantDesc>, // ordered cases: [(name, Option<TypeId>)]
    fn_sigs: Vec<FnSig>,        // [(params: Vec<TypeId>, ret: TypeId)]
    fns:     Vec<FnDesc>,       // name, sym, kind, self, params: Vec<(name,TypeId)>, ret: TypeId, throws
}
```

`postcard::to_stdvec(&meta)` becomes the bytes embedded in the `.jac_bridge` link
section. `_blob.jac` postcard-decodes it into mirrored `obj` types. Adding a field
to the model is a struct edit on one side and a mirror-obj edit on the other, both
caught by the drift test.

## One wire codec = postcard, driven by the table

Runtime values cross as postcard. Postcard is compact and NOT self-describing:
decode is schema-directed, which is exactly what walking a `TypeNode` gives us.
The Rust shim side is `serde` derive (no hand-written encode). The Jac side is one
`decode_value(node, reader)` that mirrors postcard per kind:

```
bool           1 byte (0/1)
sN / uN        postcard varint (zigzag for signed), decoded then narrowed per KIND
f32 / f64      4 / 8 bytes IEEE-754 LE
char           varint u32 codepoint
str            varint len + utf-8
bytes          varint len + raw
option         1 byte present, then value iff present    (nullable scalars)
result         1 byte discriminant, then ok or err value
list           varint count, then count * value
map            varint count, then count * (key ++ value)
tuple/record   each element/field in declared order
variant        varint discriminant, then payload iff present
handle         u64 (opaque, passed as a raw slot, not postcard-owned)
```

Handles stay a raw `u64` slot (they are process-local pointers, not serializable
values). Everything else, including composites and nesting, is postcard both ways.
The presence-flag `option` encoding is what unlocks `Option<int|bool|f64>`.

Return path: a non-void return that is not a bare handle crosses as one owned
`JacBuf` holding the postcard image, freed via the module `free_buf`. A bare
handle keeps the fast `out_handle: u64` slot. Param path: symmetric, the same
codec runs on inputs, which is what makes collection/struct PARAMS fall out for
free instead of being a new case.

## The shared model in code (kills the four hand written readers)

### Rust (macro + binder)

New shared crate `jac-bridge-typemodel`:

- `enum TypeNode` (the WIT-shaped kinds) plus a `TypeTable` builder that interns
  nodes and returns `TypeId`s.
- `serde` derives for `BridgeMeta` and every desc type; postcard emit.
- A recursive `emit_encode(TypeId) -> TokenStream` / `emit_decode(TypeId)` for the
  macro's shim generator, so a shim never special-cases a shape (or, where serde
  can carry the value directly, the shim just serde-serializes the Rust value).

The macro's `Tag` enum and the binder's `ScalarType` / `BridgeReturn` are deleted.
Both classify a Rust type into a `TypeId` against a shared `TypeTable` and emit
through the same serializer. A new supported shape is added once, in the shared
classifier, and both front ends get it.

### Jac (CPython loader + native synth)

- `_blob.jac`: one postcard reader (varints, len-prefixed, structs) that decodes
  `BridgeMeta` into mirror `obj` types. The v1 tag helpers (`tag_is_ref`, etc.)
  are deleted.
- New `_marshal.jac`: `encode_value(node, val)` / `decode_value(node, reader)`,
  the single schema-directed postcard codec, plus the postcard reader/writer
  primitives.
- `_ctypes_codegen.jac` walks `TypeNode`s and calls the shared codec at runtime
  (ctypes is interpreted).
- `_synth.jac` is codegen: it emits `.jac` source. The shared artifact for it is
  the type model plus a Jac-source emitter that calls the same `_marshal.jac`
  helpers in the generated code. Native and CPython therefore share the codec, not
  a copy of it.

Note the native path is code generation, not interpretation, so the unification is
"one type model + shared emitters that both call one `_marshal.jac`," not "one
runtime function." This is the corrected framing from the first draft.

## Sequencing

Each phase ships across all four consumers (macro accept + emit, binder classify +
emit, CPython marshal, native marshal) with a seed crate and a conformance test
(CPython byte-identity floor, native where the runtime allows). Native lags where
it must and takes an honest skip, exactly as dict-return does today.

- Phase 0  Foundation. `jac-bridge-typemodel` crate, WIT-shaped `TypeNode`,
           serde/postcard metadata, Jac postcard reader, shared `_marshal.jac`.
           Re-express every existing v1 shape on the new model and DELETE v1
           (schema constants, manual layout, tag helpers, dual paths). Regenerate
           every in-tree seed to v2. Green regression on the existing conformance
           suite proves the cutover. No new user-facing types. Largest chunk.
- Phase 1  Floats (f32 / f64).
- Phase 2  Bytes (`Vec<u8>` / `&[u8]` <-> Jac bytes).
- Phase 3  Nullable scalars: `Option<int|bool|float|char>`; general `Option<T>`;
           generalized `Result<T,E>` via the `Result` node.
- Phase 4  Nested containers (`list[list]`, `map[str,list]`, ...) and collection
           PARAMS (`Vec` / `HashMap` / slice inputs), both from the recursive codec.
- Phase 5  Tuples.
- Phase 6  Record (struct by value) and Variant (enum) marshaling. Jac surface:
           record -> object, variant -> tagged object (decide at Phase 6).
- Phase 7  Real callback signature model (`Func` / FnSig). Generalize the
           trampoline in both runtimes beyond the fixed `str -> str` replacer.

## Phase 0 commit breakdown (reviewable in stages)

1. `jac-bridge-typemodel` crate: `TypeNode`, `TypeTable`, desc types, serde
   derives, postcard emit, `TypeId` interning. Unit tests on round-trip.
2. Macro: build a `TypeTable` and emit `BridgeMeta` via postcard; delete `Tag`.
   Shim generator uses shared emit helpers. Existing macro UI tests still pass
   (their accept/reject behavior is unchanged).
3. `_blob.jac`: postcard reader + `BridgeMeta` mirror objs; delete v1 tag layout.
4. `_marshal.jac`: schema-directed codec; `_ctypes_codegen.jac` consumes it.
5. `_synth.jac`: emit generated `.jac` that calls `_marshal.jac`.
6. Binder: classify to `TypeId`, emit v2; delete `ScalarType` / `BridgeReturn`.
7. Regenerate all seeds; run the full conformance suite; delete `jac-bridge-schema`
   v1 constants and `test_abi_drift`'s v1 assumptions (replace with a serde/mirror
   drift check).

## Risks

- Jac postcard reader is new surface (varints, zigzag). Bounded and well specified;
  cover it with direct unit tests before wiring the loaders.
- Native runtime gaps (floats, nested dict-return) may force honest skips in later
  phases, as today. Phase 0 itself introduces no new value shapes, so the native
  regression is purely a re-encoding of shapes it already handles.
- Postcard varint changes the wire bytes vs v1 fixed-width slots, so v1
  byte-identity fixtures are rewritten against v2 vectors (expected under cutover).
