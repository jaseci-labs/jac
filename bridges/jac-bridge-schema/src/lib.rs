//! D2 ABI schema — canonical numeric constants for the jac-bridge wire format.
//!
//! Every crate that generates or parses D2 blobs (jac-bridge proc macro,
//! jac-bridge-regex build script, jac-bridge-inspect) imports from here.
//! The in-compiler Jac parser (jaclang/compiler/rust_bridge/_blob.jac) mirrors
//! these values; update both if the ABI evolves. The `test_abi_drift.jac` guard
//! in jac-bridge-loader parses this file and fails CI if the two sides diverge.

pub const MAGIC: &[u8; 8] = b"JACBRDG1";
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
