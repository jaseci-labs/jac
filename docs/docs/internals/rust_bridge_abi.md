# Rust Bridge ABI v1

This document specifies the binary interface between Jac-compiled programs and
hand-written or proc-macro-generated Rust bridge crates (`jac-bridge-*`).  It
is authoritative for tooling that reads, generates, or validates bridge
libraries - including the `jac-bridge-inspect` diagnostic tool (M1), the
`#[jac::bridge]` proc macro (M2), and the Jac-side FFI loader (M3).

---

## 1. Concepts

### Opaque handles

Rust objects that cross the boundary are heap-allocated (`Box<T>`) and cast to
`u64`.  The host language holds an integer token; the object never moves or is
copied across the boundary.

**Invariants:**

- `0` is always an invalid handle (never returned on success).
- The handle owner must call the corresponding `_drop` shim exactly once.
- Dropping a `0` handle is a safe no-op (all drop shims guard on zero).
- All opaque types must implement `Send` (enforced by a compile-time assertion
  in the bridge crate).

### Strings

Strings cross the boundary as a `(ptr: *const u8, len: u32)` pair:

- UTF-8, **no NUL terminator**, no embedded-NUL reliance.
- The host encodes before calling; the bridge reads exactly `len` bytes.
- Return strings come back in a `JacBuf` owned by the bridge allocator.

### JacBuf

```c
// #[repr(C)]
struct JacBuf {
    ptr: u64,   // pointer as integer (avoids ctypes None-ification of null void*)
    len: u32,
    cap: u32,
};
// 64-bit layout: ptr@0 (8 B), len@8 (4 B), cap@12 (4 B) → 16 bytes total
```

`JacBuf` is a heap buffer **owned by the bridge library**.  The caller must
free it with `jac_<module>_free_buf`; no other allocator may free it.  The
allocator boundary is the `cdylib`: do not pass `JacBuf` values between two
different bridge libraries.

---

## 2. Status codes

Every fallible C-ABI shim returns an `i32` status:

| Value | Constant      | Meaning                                               |
|-------|---------------|-------------------------------------------------------|
| 0     | `STATUS_OK`   | Success; output written to out-params.                |
| 1     | `STATUS_ERR`  | Recoverable error; `*out_err` holds an error handle.  |
| 2     | `STATUS_PANIC`| Rust panic was caught; `*out_err` holds a message.   |

`STATUS_PANIC` means the bridge caught an unwinding panic with
`std::panic::catch_unwind`.  The panic handle contains a plain string message
(`Box<String>` cast to `u64`), the same representation as an error handle.  It
is read with `jac_<module>_panic_message` and freed with
`jac_<module>_panic_drop`.  These two symbols are emitted for **every** bridge,
independent of whether it declares a `#[jac_error]` type, so a panic in a bridge
with no error type still surfaces its message and frees its handle rather than
leaking behind a generic status string.  The Rust release profile must keep
`panic = "unwind"` so that panics unwind rather than aborting.

---

## 3. Shim naming convention

All shim symbols are prefixed with `jac_<module>_` to avoid collisions when a
program imports multiple bridges simultaneously.

| Symbol form                          | Purpose                            |
|--------------------------------------|------------------------------------|
| `jac_<mod>_<Type>_new`               | Constructor                        |
| `jac_<mod>_<Type>_<method>`          | Instance method                    |
| `jac_<mod>_<Type>_drop`              | Destructor (called by synthesized dtor) |
| `jac_<mod>_error_message`            | Copy error handle → `JacBuf` (with `#[jac_error]`) |
| `jac_<mod>_error_drop`               | Free an error handle (with `#[jac_error]`) |
| `jac_<mod>_panic_message`            | Copy panic handle → `JacBuf` (always emitted) |
| `jac_<mod>_panic_drop`               | Free a panic handle (always emitted) |
| `jac_<mod>_free_buf`                 | Free a `JacBuf`                    |
| `jac_bridge_init_<mod>`              | Return pointer to D2 metadata blob |

### Constructor signature

```c
i32 jac_<mod>_<Type>_new(
    /* pattern args ... */,
    u64 *out_handle,
    u64 *out_err,
);
```

On `STATUS_OK`: `*out_handle` is the new opaque handle; `*out_err = 0`.
On `STATUS_ERR`: `*out_handle = 0`; `*out_err` is an error handle.
On `STATUS_PANIC`: same shape as `STATUS_ERR`.

### Instance method signature (non-string return)

```c
i32 jac_<mod>_<Type>_<method>(
    u64 handle,
    /* args ... */,
    <RetType> *out_result,
    u64 *out_err,
);
```

### Instance method signature (string return via JacBuf)

```c
i32 jac_<mod>_<Type>_<method>(
    u64 handle,
    /* args ... */,
    JacBuf *out_buf,
    u64 *out_err,
);
```

The caller owns the returned `JacBuf` and must free it with
`jac_<mod>_free_buf`.

### Destructor

```c
void jac_<mod>_<Type>_drop(u64 handle);
```

Idempotent on `0`.  The M3 codegen synthesises a call to this from the Jac
object's RC destructor.

---

## 4. D2 metadata section

Every bridge library embeds a binary metadata blob in a named section so that
cross-compiling toolchains and diagnostic tools can parse the bridge API from
the ELF/Mach-O/PE file **without executing the library**.

### Section names

| Platform | Section name         |
|----------|----------------------|
| Linux    | `.jac_bridge`        |
| macOS    | `__DATA,__jac_bridge`|
| Windows  | `.jacbrdg`           |

### Init function

```c
const u8 *jac_bridge_init_<module>(void);
```

Returns a pointer to the first byte of the metadata blob embedded in the
section.  Calling this is the runtime path; reading the ELF section is the
cross-compile/tooling path.  Both must agree on the blob contents.

The `#[used]` attribute on the static and the live reference from the init
function together prevent the linker from discarding the section with
`--gc-sections`.

---

## 5. D2 blob format

All multi-byte integers are **little-endian**.  All offsets are **absolute
byte offsets within the blob** (not relative).  Strings are **not NUL
terminated**.

### 5.1 Header (56 bytes, at offset 0)

| Offset | Size | Field        | Notes                                  |
|--------|------|--------------|----------------------------------------|
| 0      | 8    | `magic`      | ASCII `JACBRDG1`                       |
| 8      | 4    | `abi_version`| Currently `1`                          |
| 12     | 4    | `header_size`| Byte size of this header (currently 56)|
| 16     | 4    | `blob_len`   | Total byte size of the blob            |
| 20     | 4    | `blob_crc32` | CRC-32 of blob (M0: 0, not computed)   |
| 24     | 8    | `module_name`| `StrRef` - Jac-visible module name     |
| 32     | 8    | `api_checksum`| u64 (M0: 0, not computed)             |
| 40     | 4    | `types_offset`| Absolute offset of first `TypeDesc`   |
| 44     | 4    | `types_count`| Number of `TypeDesc` entries           |
| 48     | 4    | `fns_offset` | Absolute offset of first `FnDesc`      |
| 52     | 4    | `fns_count`  | Number of `FnDesc` entries             |

**`StrRef`** is a pair `(offset: u32, len: u32)` where `offset` is the
absolute byte offset of the string within the blob and `len` is the byte
length (no NUL).

### 5.2 TypeDesc (32 bytes each)

`TypeDesc` entries are contiguous starting at `types_offset`.  Each entry
begins with `desc_size` which allows future versions to grow the struct while
remaining forward-compatible.

| Offset | Size | Field         | Notes                                  |
|--------|------|---------------|----------------------------------------|
| 0      | 4    | `desc_size`   | Byte size of this entry (currently 32) |
| 4      | 1    | `kind`        | `0`=opaque, `3`=error (see §5.5)      |
| 5      | 3    | (padding)     | Reserved, must be zero                 |
| 8      | 8    | `name`        | `StrRef` - Jac-visible type name       |
| 16     | 8    | `drop_symbol` | `StrRef` - C symbol for destructor     |
| 24     | 4    | `members_offset`| Absolute offset of member array (M0: 0)|
| 28     | 4    | `members_count`| Number of members (M0: 0)             |

### 5.3 FnDesc (44 bytes each)

`FnDesc` entries are contiguous starting at `fns_offset`.

| Offset | Size | Field           | Notes                                    |
|--------|------|-----------------|------------------------------------------|
| 0      | 4    | `desc_size`     | Byte size of this entry (currently 44)   |
| 4      | 8    | `name`          | `StrRef` - Jac-visible function name     |
| 12     | 8    | `symbol`        | `StrRef` - C ABI symbol name             |
| 20     | 4    | `self_type`     | `TypeTag` of receiver, or `NONE`         |
| 24     | 1    | `kind`          | `0`=ctor, `1`=method (see §5.5)          |
| 25     | 3    | (padding)       | Reserved, must be zero                   |
| 28     | 4    | `throws`        | `TypeTag` of error type, or `NONE`       |
| 32     | 4    | `ret`           | `TypeTag` of return type                 |
| 36     | 4    | `params_offset` | Absolute offset of first `ParamDesc`     |
| 40     | 4    | `params_count`  | Number of `ParamDesc` entries            |

### 5.4 ParamDesc (12 bytes each)

`ParamDesc` entries are contiguous starting at the `params_offset` in the
enclosing `FnDesc`.  Multiple `FnDesc` entries may share a contiguous run of
`ParamDesc`s, or each may have its own.

| Offset | Size | Field  | Notes                           |
|--------|------|--------|---------------------------------|
| 0      | 8    | `name` | `StrRef` - parameter name       |
| 8      | 4    | `ty`   | `TypeTag` of parameter type     |

### 5.5 TypeTag encoding

`TypeTag` is a `u32` that encodes a type reference:

| Value              | Meaning                                         |
|--------------------|-------------------------------------------------|
| `0x00000001`       | `bool`                                          |
| `0x00000004`       | `str`                                           |
| `0xFFFFFFFF`       | Absent / no type (`NONE` sentinel)              |
| `0x80000000 \| i`  | Reference to `TypeDesc[i]` (index 0-based)      |

### 5.6 Kind constants

**TypeDesc kind:**

| Value | Name     | Meaning                                           |
|-------|----------|---------------------------------------------------|
| 0     | `opaque` | Opaque handle (Box<T>); only accessible via shims |
| 3     | `error`  | Error type; implements the error protocol         |

**FnDesc kind:**

| Value | Name     | Meaning                                              |
|-------|----------|------------------------------------------------------|
| 0     | `ctor`   | Constructor; `self_type` must be `NONE`              |
| 1     | `method` | Instance method; `self_type` is the receiver type    |

### 5.7 String pool

Strings are packed contiguously after all descriptors.  The pool starts at
`pool_base` (currently 276 for the regex bridge) and runs to `blob_len`.
`StrRef.offset` values are absolute offsets into the blob, so code reading
strings does not need to know `pool_base`.

---

## 6. regex bridge layout (ABI v1, blob_len=431)

This section documents the concrete layout of `libjac_bridge_regex` as an
example and a regression anchor.

```
Offset  Size  Content
------  ----  -------
0       56    Header (magic="JACBRDG1", abi_version=1, module="regex",
                       types={off=56,count=2}, fns={off=120,count=3})
56      32    TypeDesc[0]: Regex  (opaque, drop=jac_regex_Regex_drop)
88      32    TypeDesc[1]: RegexError  (error, drop=jac_regex_error_drop)
120     44    FnDesc[0]: new(pattern:str)->Regex  [ctor, throws=RegexError,
                         sym=jac_regex_Regex_new, params@252,count=1]
164     44    FnDesc[1]: is_match(text:str)->bool  [method/Regex,
                         sym=jac_regex_Regex_is_match, params@264,count=1]
208     44    FnDesc[2]: message()->str  [method/RegexError,
                         sym=jac_regex_error_message, params empty]
252     12    ParamDesc[0]: pattern: str
264     12    ParamDesc[1]: text: str
276     155   String pool: "regex","Regex","jac_regex_Regex_drop",
                           "RegexError","jac_regex_error_drop","new",
                           "jac_regex_Regex_new","is_match",
                           "jac_regex_Regex_is_match","message",
                           "jac_regex_error_message","pattern","text"
431     ---   (end)
```

---

## 7. ABI stability policy

- Fields within an existing descriptor must never be reordered or resized.
- New optional fields may be appended to a descriptor; `desc_size` advances.
- New `TypeTag` values occupy previously-zero ranges; parsers must treat unknown
  tags as opaque.
- `abi_version` increments on any breaking change to the header or blob format.
- The `blob_crc32` and `api_checksum` fields are reserved for a future
  integrity-checking pass (M1+).

---

## 8. Tooling

### jac-bridge-inspect

`jac-bridge-inspect <lib.so>` reads the `.jac_bridge` ELF section from a
bridge library and pretty-prints the D2 metadata without executing the library.

```
$ jac-bridge-inspect bridges/target/release/libjac_bridge_regex.so

jac-bridge-inspect  bridges/target/release/libjac_bridge_regex.so

  ABI version : 1
  Module      : regex
  Blob length : 431
  Types       : 2
  Functions   : 3

Types:
  [0]  Regex         opaque  drop=jac_regex_Regex_drop
  [1]  RegexError    error   drop=jac_regex_error_drop

Functions:
  [0]  new(pattern: str) -> Regex      ctor    sym=jac_regex_Regex_new  throws=RegexError
  [1]  is_match(text: str) -> bool     method  self=Regex  sym=jac_regex_Regex_is_match
  [2]  message() -> str                method  self=RegexError  sym=jac_regex_error_message
```

The tool exits `0` on success, `1` on any parse error, `2` if no `.jac_bridge`
section is found.
