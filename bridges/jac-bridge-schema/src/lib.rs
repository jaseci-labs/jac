//! D2 ABI schema — canonical numeric constants for the jac-bridge wire format.
//!
//! Every crate that generates or parses D2 blobs (jac-bridge proc macro,
//! jac-bridge-regex build script, jac-bridge-inspect) imports from here.
//! The Python parser (_blob.py) mirrors these values with a cross-reference
//! comment; update both if the ABI evolves.

pub const MAGIC: &[u8; 8] = b"JACBRDG1";
pub const ABI_VERSION: u32 = 1;

// TypeTag values (u32, stored in StrRef / tag fields)
pub const TAG_BOOL: u32 = 1;
pub const TAG_STR: u32 = 4;
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

// TypeKind values (u8, byte 4 of each TypeDesc)
pub const KIND_OPAQUE: u8 = 0;
pub const KIND_ERROR: u8 = 3;

// FnKind values (u8, byte 24 of each FnDesc)
pub const FN_CTOR: u8 = 0;
pub const FN_METHOD: u8 = 1;
