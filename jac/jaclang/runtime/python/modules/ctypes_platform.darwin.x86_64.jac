import from c {
    obj ffi_type_record;  glob ffi_type_longdouble: ffi_type_record,
         ffi_type_complex_longdouble: ffi_type_record; def ldexp(
        value: f64, exponent: i32
    ) -> f64;  def frexp(value: f64, exponent: &mut i32) -> f64;  def copysign(
        x: f64, y: f64
    ) -> f64;  def _dyld_shared_cache_contains_path(path: ptr[u8]) -> bool;
}

glob FFI_DEFAULT_ABI: i32 = 2,
     SIZEOF_LONG_DOUBLE: i64 = 16,
     ALIGNOF_LONG_DOUBLE: i64 = 16,
     RTLD_LOCAL: i32 = 0x4,
     RTLD_GLOBAL: i32 = 0x8,
     RTLD_NOW: i32 = 0x2,
     LONG_DOUBLE_IS_DOUBLE: bool = False,
     MAX_STRUCT_SIZE: i64 = 16,
     PASS_BY_REF_HACK: bool = False,
     HAS_DYLD_SHARED_CACHE: bool = True;

def long_double_load(src: ptr) -> f64;

def long_double_store(dst: ptr, value: f64);

def ffi_type_longdouble_ref -> ptr;

def ffi_type_complex_longdouble_ref -> ptr;

def dyld_shared_cache_contains_path(path: ptr[u8]) -> bool;

impl long_double_load(src: ptr) -> f64 {
    significand = ptr[u64](src).view(1)[0];
    sign_exponent = ptr[u16](ptr[u8](src) + 8).view(1)[0];
    negative = (sign_exponent >> 15) != 0;
    exponent = i32(sign_exponent & 0x7FFF);
    result: f64 = 0.0;
    if exponent == 0x7FFF {
        infinity = ldexp(1.0, 4096);
        if (significand & 0x7FFFFFFFFFFFFFFF) == 0 {
            result = infinity;
        } else {
            result = infinity - infinity;
        }
    } elif exponent == 0 {
        result = ldexp(f64(significand), i32(1 - 16383 - 63));
    } else {
        result = ldexp(f64(significand), exponent - i32(16383 + 63));
    }
    if negative {
        return -result;
    }
    return result;
}

impl long_double_store(dst: ptr, value: f64) {
    negative = copysign(1.0, value) < 0.0;
    sign: u16 = 0;
    if negative {
        sign = 0x8000;
    }
    significand: u64 = 0;
    exponent: u16 = 0;
    if value != value {
        significand = 0xC000000000000000;
        exponent = 0x7FFF;
    } elif value == ldexp(1.0, 4096) or value == -ldexp(1.0, 4096) {
        significand = 0x8000000000000000;
        exponent = 0x7FFF;
    } elif value != 0.0 {
        e: i32 = 0;
        fraction = frexp(abs(value), &mut e);
        significand = u64(ldexp(fraction, 64));
        exponent = u16(e - 1 + 16383);
    }
    ptr[u64](dst).view(1)[0] = significand;
    ptr[u16](ptr[u8](dst) + 8).view(1)[0] = sign | exponent;
}

impl ffi_type_longdouble_ref -> ptr {
    return ptr(addressof(ffi_type_longdouble));
}

impl ffi_type_complex_longdouble_ref -> ptr {
    return ptr(addressof(ffi_type_complex_longdouble));
}

impl dyld_shared_cache_contains_path(path: ptr[u8]) -> bool {
    return _dyld_shared_cache_contains_path(path);
}
