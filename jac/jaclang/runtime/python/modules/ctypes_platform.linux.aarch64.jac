import from c {
    obj ffi_type_record;  glob ffi_type_longdouble: ffi_type_record,
         ffi_type_complex_longdouble: ffi_type_record; def ldexp(
        value: f64, exponent: i32
    ) -> f64;  def frexp(value: f64, exponent: &mut i32) -> f64;  def copysign(
        x: f64, y: f64
    ) -> f64;
}

glob FFI_DEFAULT_ABI: i32 = 1,
     SIZEOF_LONG_DOUBLE: i64 = 16,
     ALIGNOF_LONG_DOUBLE: i64 = 16,
     RTLD_LOCAL: i32 = 0,
     RTLD_GLOBAL: i32 = 0x100,
     RTLD_NOW: i32 = 2,
     LONG_DOUBLE_IS_DOUBLE: bool = False,
     MAX_STRUCT_SIZE: i64 = 32,
     PASS_BY_REF_HACK: bool = True,
     HAS_DYLD_SHARED_CACHE: bool = False;

def long_double_load(src: ptr) -> f64;

def long_double_store(dst: ptr, value: f64);

def ffi_type_longdouble_ref -> ptr;

def ffi_type_complex_longdouble_ref -> ptr;

def dyld_shared_cache_contains_path(path: ptr[u8]) -> bool;

impl long_double_load(src: ptr) -> f64 {
    low = ptr[u64](src).view(1)[0];
    high = ptr[u64](ptr[u8](src) + 8).view(1)[0];
    negative = (high >> 63) != 0;
    exponent = i32((high >> 48) & 0x7FFF);
    fraction_high = high & 0xFFFFFFFFFFFF;
    result: f64 = 0.0;
    if exponent == 0x7FFF {
        infinity = ldexp(1.0, 4096);
        if fraction_high == 0 and low == 0 {
            result = infinity;
        } else {
            result = infinity - infinity;
        }
    } else {
        significand = (fraction_high << 15) | (low >> 49);
        if (low & 0x1FFFFFFFFFFFF) != 0 {
            significand = significand | 1;
        }
        if exponent == 0 {
            result = ldexp(f64(significand), i32(1 - 16383 - 63));
        } else {
            significand = significand | 0x8000000000000000;
            result = ldexp(f64(significand), exponent - i32(16383 + 63));
        }
    }
    if negative {
        return -result;
    }
    return result;
}

impl long_double_store(dst: ptr, value: f64) {
    high: u64 = 0;
    low: u64 = 0;
    if copysign(1.0, value) < 0.0 {
        high = 0x8000000000000000;
    }
    if value != value {
        high = 0x7FFF800000000000;
    } elif value == ldexp(1.0, 4096) or value == -ldexp(1.0, 4096) {
        high = high | 0x7FFF000000000000;
    } elif value != 0.0 {
        e: i32 = 0;
        fraction = frexp(abs(value), &mut e);
        significand = u64(ldexp(fraction, 53));
        bits = significand & 0xFFFFFFFFFFFFF;
        high = high | (u64(e - 1 + 16383) << 48) | (bits >> 4);
        low = (bits & 0xF) << 60;
    }
    ptr[u64](dst).view(1)[0] = low;
    ptr[u64](ptr[u8](dst) + 8).view(1)[0] = high;
}

impl ffi_type_longdouble_ref -> ptr {
    return ptr(addressof(ffi_type_longdouble));
}

impl ffi_type_complex_longdouble_ref -> ptr {
    return ptr(addressof(ffi_type_complex_longdouble));
}

impl dyld_shared_cache_contains_path(path: ptr[u8]) -> bool {
    return False;
}
