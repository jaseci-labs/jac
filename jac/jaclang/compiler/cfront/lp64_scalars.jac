"""Shared LP64 C name → FFI scalar map for bindgen and c2jac lift.

Matched by typedef *name* ahead of alias resolution so placeholder or
porting typedef spellings both map to the same widths (native LP64 only).
"""

glob LP64_SCALARS: dict[str, str] = {
         "int8_t": "i8",
         "uint8_t": "u8",
         "int16_t": "i16",
         "uint16_t": "u16",
         "int32_t": "i32",
         "uint32_t": "u32",
         "int64_t": "i64",
         "uint64_t": "u64",
         "intmax_t": "i64",
         "uintmax_t": "u64",
         "intptr_t": "i64",
         "uintptr_t": "u64",
         "ptrdiff_t": "i64",
         "size_t": "u64",
         "ssize_t": "i64",
         "Py_ssize_t": "i64",
         "Py_hash_t": "i64",

     };

def lp64_ffi_scalar(name: str) -> str | None {
    return LP64_SCALARS.get(name, None);
}
