import from c { def _dyld_shared_cache_contains_path(path: ptr[u8]) -> bool;  }

glob FFI_DEFAULT_ABI: i32 = 1,
     SIZEOF_LONG_DOUBLE: i64 = 8,
     ALIGNOF_LONG_DOUBLE: i64 = 8,
     RTLD_LOCAL: i32 = 0x4,
     RTLD_GLOBAL: i32 = 0x8,
     RTLD_NOW: i32 = 0x2,
     LONG_DOUBLE_IS_DOUBLE: bool = True,
     MAX_STRUCT_SIZE: i64 = 32,
     PASS_BY_REF_HACK: bool = True,
     HAS_DYLD_SHARED_CACHE: bool = True;

def long_double_load(src: ptr) -> f64;

def long_double_store(dst: ptr, value: f64);

def ffi_type_longdouble_ref -> ptr;

def ffi_type_complex_longdouble_ref -> ptr;

def dyld_shared_cache_contains_path(path: ptr[u8]) -> bool;

impl long_double_load(src: ptr) -> f64 {
    return ptr[f64](src).view(1)[0];
}

impl long_double_store(dst: ptr, value: f64) {
    ptr[f64](dst).view(1)[0] = value;
}

impl ffi_type_longdouble_ref -> ptr {
    return ptr();
}

impl ffi_type_complex_longdouble_ref -> ptr {
    return ptr();
}

impl dyld_shared_cache_contains_path(path: ptr[u8]) -> bool {
    return _dyld_shared_cache_contains_path(path);
}
