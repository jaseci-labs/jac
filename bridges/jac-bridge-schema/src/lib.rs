//! D2 ABI schema — canonical numeric constants for the jac-bridge wire format.
//!
//! Every crate that generates or parses D2 blobs (jac-bridge proc macro,
//! jac-bridge-regex build script, jac-bridge-inspect) imports from here.
//! The in-compiler Jac parser (jaclang/compiler/rust_bridge/_blob.jac) mirrors
//! these values; update both if the ABI evolves. The `test_abi_drift.jac` guard
//! in jac-bridge-loader parses this file and fails CI if the two sides diverge.

pub const MAGIC: &[u8; 8] = b"JACBRDG1";
// ─── ABI v1 is FROZEN (Phase 2.12) ──────────────────────────────────────────
//
// As of the serde wide lane (Phase 2), the v1 wire format is declared FROZEN.
// The scalar TypeTag space (1..=8: BOOL/INT/UINT/STR/FN/F64/BYTES/WIDE) is full
// and no further scalar tag will be added; the top-6 flag bits
// (REF/OPT/MAP/LIST/SHARED/BORROW) are likewise fixed. TAG_WIDE=8 is the
// designated growth valve: any future Rust shape that needs to cross the
// boundary rides the self-describing MessagePack payload behind that ONE tag
// rather than earning a new tag. The typed-record table (below) is the pattern
// every future extension follows — it added a whole typed-object capability
// with ZERO new wire tags, purely by (a) reusing TAG_WIDE and (b) appending a
// section located through a previously-reserved, zero-by-default header word.
//
// The evolution rule (D2) is therefore append-only WITHIN v1: new blob sections
// hang off reserved/zero header slots that old loaders skip, and new semantics
// ride TAG_WIDE's payload. Anything that cannot be expressed that way — a change
// to an EXISTING field's meaning, a new scalar tag, a wider FnDesc/TypeDesc —
// is a breaking change and MUST bump ABI_VERSION (and the MAGIC's trailing
// digit). Both sides of the ABI (this file and the in-compiler Jac parser
// jaclang/compiler/rust_bridge/_blob.jac) are kept in lockstep by
// test_abi_drift.jac.
pub const ABI_VERSION: u32 = 1;

// TypeTag values (u32, stored in StrRef / tag fields)
pub const TAG_BOOL: u32 = 1;
/// A signed integer scalar (`i8`..`i64`, `isize`).  Crosses the boundary as a
/// single 64-bit slot, sign-extended to the full width; the loader decodes it as
/// two's-complement signed.  Param and return.  Additive to ABI v1.
pub const TAG_INT: u32 = 2;
/// An unsigned integer scalar (`u8`..`u64`, `usize`).  Crosses as a single
/// 64-bit slot, zero-extended; the loader decodes it as unsigned.  Distinct from
/// [`TAG_INT`] so a full-range `u64` (high bit set) is not misread as negative.
/// Param and return.  Additive to ABI v1.
pub const TAG_UINT: u32 = 3;
pub const TAG_STR: u32 = 4;
/// A callback function pointer parameter (`JacCallback`).  Crosses the boundary
/// as a single `u64` C function pointer with the fixed signature
/// `fn(*const u8, u32, *mut JacBuf, *mut u64) -> i32` (match text in, replacement
/// out-slot, error out).  Param-only — never a return tag.  Additive to ABI v1.
pub const TAG_FN: u32 = 5;
/// A 64-bit IEEE-754 float scalar (`f32`, `f64`).  Crosses the boundary as a
/// single 64-bit slot carrying the value's **bit pattern** (`f64::to_bits`), not
/// a numeric cast — a numeric `as u64` would truncate the double to an integer.
/// An `f32` is value-preservingly widened to `f64` first, so a narrow float
/// round-trips through the wider slot exactly.  The loader reconstructs the
/// double with `f64::from_bits`.  Param and return.  Additive to ABI v1.
pub const TAG_F64: u32 = 6;
/// An owned byte string (`Vec<u8>` return, `&[u8]` param).  Crosses the boundary
/// with the SAME wire shape as [`TAG_STR`] — `(ptr, len)` as a param, an owned
/// `JacBuf { ptr, len, cap }` as a return — but is decoded on the loader side as
/// raw bytes, **never** UTF-8 and **never** by `strlen`: the explicit `len`
/// carries embedded NULs faithfully (msgpack / hash digests / any binary blob).
/// The loader materializes it as a Jac `bytes` rather than a `str`.  Param and
/// return; `Option<Vec<u8>>` signals `None` in-band with a null `JacBuf.ptr` on an
/// OK status, exactly like `Option<String>`.  Additive to ABI v1 — old blobs never
/// set it (append-only evolution rule, D2).
pub const TAG_BYTES: u32 = 7;
/// A `serde::Serialize` / `Deserialize` Rust value crossing the boundary as a
/// self-describing **MessagePack** document (`rmp_serde`).  This is the "wide"
/// lane (Phase 2): instead of a hand-written marshaling arm per shape, ANY
/// serde type — structs, enums, nested/optional fields, `chrono`-with-serde,
/// third-party types deriving serde — rides the ONE msgpack carrier.  Wire
/// shape is identical to [`TAG_BYTES`]: `(ptr, len)` as a param, an owned
/// `JacBuf { ptr, len, cap }` as a return; the payload bytes are a MessagePack
/// blob rather than a raw digest.  The loader does NOT hand back a `bytes` —
/// it *decodes* the msgpack into a native Jac value (dict / list / scalar,
/// and later a synthesized typed object, Phase 2.6) on both the na and CPython
/// loaders.  Param and return; `Option<T>` signals `None` in-band with a null
/// `JacBuf.ptr` on an OK status, exactly like [`TAG_STR`] / [`TAG_BYTES`].
/// This is the LAST additive scalar tag of ABI v1 — with it the v1 scalar tag
/// space (1..=8) is frozen; any further wire evolution bumps [`ABI_VERSION`].
/// Additive to ABI v1 — old blobs never set it (append-only evolution rule, D2).
pub const TAG_WIDE: u32 = 8;
/// Bit shift for the 1-based **record id** packed into a `TAG_WIDE` slot tag
/// (Phase 2.9, typed-obj synthesis). A wide value whose Rust type is an
/// `#[automatically_derived]` serde struct with NO stripped/private fields has a
/// statically known field shape, so the binder emits `TAG_WIDE | (record_id <<
/// TAG_WIDE_REC_SHIFT)`; the id indexes the blob's **record table** (name +
/// field list). `record_id == 0` (a bare `TAG_WIDE`) is the ABI-v1 behaviour: the
/// value crosses as a DYNAMIC document (dict / JacValue), field shape unknown.
/// The WIRE is unchanged either way — still one `rmp_serde` msgpack `JacBuf`; the
/// id only tells the loader to decode into a typed object instead of a dict. The
/// id occupies bits [8..26), below the top-6 flag region, so it never collides
/// with the `Ref`/`Opt`/`Map`/`List`/`Shared`/`Borrow` bits. Additive to ABI v1
/// (append-only, D2): old blobs set no id, and a loader that ignores the id still
/// decodes the identical bytes dynamically.
pub const TAG_WIDE_REC_SHIFT: u32 = 8;
/// Mask for the record id after shifting out [`TAG_WIDE_REC_SHIFT`] (18 bits,
/// bounded below [`TAG_BORROW_BIT`]).
pub const TAG_WIDE_REC_MASK: u32 = 0x0003_FFFF;
/// Sentinel meaning "no type" (absent self_type / throws / void return).
pub const TAG_VOID: u32 = 0xFFFF_FFFF;
/// OR'd with a type index to produce a type-reference tag.
pub const TAG_REF_BIT: u32 = 0x8000_0000;
/// OR'd with an inner tag to mark a nullable (`Option<T>`) return: the shim
/// signals `None` in-band (null handle for `Option<Ref>`, null `JacBuf.ptr` for
/// `Option<Str>`) with an OK status, and the loader maps it to Jac `None`.
/// Additive to ABI v1 — old blobs never set it; a blob that does requires a
/// loader that understands it (append-only evolution rule, D2).
pub const TAG_OPT_BIT: u32 = 0x4000_0000;
/// OR'd with a value tag to mark a `HashMap<String, V>` return marshaled as a
/// real Jac `dict[str, V]` (V ∈ {int, uint, str, bool}).  Keys are implicitly
/// UTF-8 strings in v1.  The shim serializes the whole map into one owned
/// `JacBuf` (`[u32 count]` then per entry `[u32 key_len][key bytes][value]`,
/// value = u64 LE for int/uint, `[u32 len][bytes]` for str, u8 for bool; all
/// little-endian) and the loader deep-copies it into a fresh dict.  Return-only.
/// Additive to ABI v1 — old blobs never set it (append-only evolution rule, D2).
pub const TAG_MAP_BIT: u32 = 0x2000_0000;
/// OR'd with an element tag to mark a `Vec<V>` return marshaled as a real Jac
/// `list[V]` (V ∈ {int, uint, str, bool}).  The shim serializes the whole vector
/// into one owned `JacBuf` (`[u32 count]` then per element `[value]`, value =
/// u64 LE for int/uint, `[u32 len][bytes]` for str, u8 for bool; all
/// little-endian) and the loader deep-copies it into a fresh list.  Return-only.
/// Additive to ABI v1 — old blobs never set it (append-only evolution rule, D2).
pub const TAG_LIST_BIT: u32 = 0x1000_0000;
/// OR'd into a `Ref` return tag to mark the returned handle as **shared** (Phase
/// S, Track A): the return is an existing RC'd inner, not a fresh owner. The
/// loader `retain`s the source handle when it adopts the return, so both
/// wrappers hold an independent reference and `close()` (a decref) frees the
/// inner exactly once at rc==0. Neither this bit nor [`TAG_BORROW_BIT`] set =
/// **owned** (the default: the wrapper owns the object and `close()` drops it).
/// Return-only. Additive to ABI v1 — old blobs never set it (append-only
/// evolution rule, D2).
pub const TAG_SHARED_BIT: u32 = 0x0800_0000;
/// OR'd into a `Ref` return tag to mark the returned handle as **borrowed**
/// (Phase S, Track A): a live, RC-pinned view into an owner's interior. Minting
/// the view `retain`s the OWNER handle (rc+1); because the owner cannot reach
/// rc==0 while the view is live, the view is always valid with no `__valid`
/// flag. Dropping the view `release`s the owner. Return-only. Additive to ABI
/// v1 — old blobs never set it (append-only evolution rule, D2).
pub const TAG_BORROW_BIT: u32 = 0x0400_0000;

// TypeKind values (u8, byte 4 of each TypeDesc)
pub const KIND_OPAQUE: u8 = 0;
pub const KIND_ERROR: u8 = 3;

// FnKind values (u8, byte 24 of each FnDesc)
pub const FN_CTOR: u8 = 0;
pub const FN_METHOD: u8 = 1;
/// A no-receiver associated function that is NOT THE constructor: an extra
/// `-> Self` factory (`Uuid::nil`/`parse_str`) or a non-`Self` static
/// (`Sha256::digest(data) -> Output`). Crosses with NO handle param (like a
/// ctor) but is dispatched by name and its return marshaled by its own tag; the
/// loader exposes it as a static method on the owning type. `self_type` carries
/// the OWNING type index (for loader placement), never a receiver.
pub const FN_STATIC: u8 = 2;

// ─── Record table (Phase 2.9, typed-obj synthesis) ──────────────────────────
//
// A NEW blob section, appended after the ParamDescs and before the string pool,
// carrying the field schema of every typed wide record. Located via two header
// words written into the previously-reserved u64 at header offset 32:
//   header[32..36] = record_off  (byte offset of the first RecordDesc, 0 if none)
//   header[36..40] = record_count
// Old readers left this u64 zero and never read it, so a blob with records is
// still parsed correctly (records ignored) by an ABI-v1-only loader — the wide
// values simply decode dynamically. Append-only (D2).
//
// RecordDesc — 20 bytes, one per typed record (1-based `record_id` = index+1):
//   +0  u32   desc size (20; lets a future reader skip an enlarged desc)
//   +4  StrRef record name (the synthesized Jac obj / Python class name)
//   +12 u32   field_off   (byte offset of this record's first FieldDesc)
//   +16 u32   field_count
// FieldDesc — 12 bytes, one per field (declaration order == msgpack map order):
//   +0  StrRef field name
//   +8  u32    field value tag (a scalar TAG_*; nested records are out of the
//              v1 typed-obj slice and keep the dynamic lane)
/// Byte size of one RecordDesc in the record table.
pub const RECORD_DESC_SIZE: u32 = 20;
/// Byte size of one FieldDesc in the record table.
pub const FIELD_DESC_SIZE: u32 = 12;
