def proxies_copy -> ptr;

def proxy_key(index: i32) -> ptr;

def cf_release(cf: ptr);

def cf_dictionary_value(dct: ptr, key: ptr) -> ptr;

def cf_number_int32(num: ptr) -> i32;

def cf_string_utf8_pointer(ref: ptr, encoding: u32) -> ptr[u8];

def cf_string_length(ref: ptr) -> i64;

def cf_string_copy(ref: ptr, buf: ptr[u8], size: i64, encoding: u32) -> bool;

def cf_array_count(array: ptr) -> i64;

def cf_array_value(array: ptr, index: i64) -> ptr;

impl proxies_copy -> ptr {
    return ptr();
}

impl proxy_key(index: i32) -> ptr {
    return ptr();
}

impl cf_release(cf: ptr) {
    return;
}

impl cf_dictionary_value(dct: ptr, key: ptr) -> ptr {
    return ptr();
}

impl cf_number_int32(num: ptr) -> i32 {
    return i32(0);
}

impl cf_string_utf8_pointer(ref: ptr, encoding: u32) -> ptr[u8] {
    return ptr[u8]();
}

impl cf_string_length(ref: ptr) -> i64 {
    return 0;
}

impl cf_string_copy(ref: ptr, buf: ptr[u8], size: i64, encoding: u32) -> bool {
    return False;
}

impl cf_array_count(array: ptr) -> i64 {
    return 0;
}

impl cf_array_value(array: ptr, index: i64) -> ptr {
    return ptr();
}
