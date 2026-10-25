import from c {
    glob kSCPropNetProxiesExcludeSimpleHostnames: ptr,
         kSCPropNetProxiesExceptionsList: ptr,
         kSCPropNetProxiesHTTPEnable: ptr,
         kSCPropNetProxiesHTTPProxy: ptr,
         kSCPropNetProxiesHTTPPort: ptr,
         kSCPropNetProxiesHTTPSEnable: ptr,
         kSCPropNetProxiesHTTPSProxy: ptr,
         kSCPropNetProxiesHTTPSPort: ptr,
         kSCPropNetProxiesFTPEnable: ptr,
         kSCPropNetProxiesFTPProxy: ptr,
         kSCPropNetProxiesFTPPort: ptr,
         kSCPropNetProxiesGopherEnable: ptr,
         kSCPropNetProxiesGopherProxy: ptr,
         kSCPropNetProxiesGopherPort: ptr,
         kSCPropNetProxiesSOCKSEnable: ptr,
         kSCPropNetProxiesSOCKSProxy: ptr,
         kSCPropNetProxiesSOCKSPort: ptr; def SCDynamicStoreCopyProxies(
        store: ptr
    ) -> ptr;  def CFRelease(cf: ptr);  def CFDictionaryGetValue(
        dct: ptr, key: ptr
    ) -> ptr;  def CFNumberGetValue(
        number: ptr, number_type: i64, value_ptr: ptr
    ) -> u8;  def CFStringGetCStringPtr(string: ptr, encoding: u32) -> ptr[u8];  def CFStringGetLength(
        string: ptr
    ) -> i64;  def CFStringGetCString(
        string: ptr, buffer: ptr[u8], size: i64, encoding: u32
    ) -> u8;  def CFArrayGetCount(array: ptr) -> i64;  def CFArrayGetValueAtIndex(
        array: ptr, index: i64
    ) -> ptr;
}

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
    return SCDynamicStoreCopyProxies(ptr());
}

impl proxy_key(index: i32) -> ptr {
    if index == 0 {
        return kSCPropNetProxiesExcludeSimpleHostnames;
    } elif index == 1 {
        return kSCPropNetProxiesExceptionsList;
    } elif index == 2 {
        return kSCPropNetProxiesHTTPEnable;
    } elif index == 3 {
        return kSCPropNetProxiesHTTPProxy;
    } elif index == 4 {
        return kSCPropNetProxiesHTTPPort;
    } elif index == 5 {
        return kSCPropNetProxiesHTTPSEnable;
    } elif index == 6 {
        return kSCPropNetProxiesHTTPSProxy;
    } elif index == 7 {
        return kSCPropNetProxiesHTTPSPort;
    } elif index == 8 {
        return kSCPropNetProxiesFTPEnable;
    } elif index == 9 {
        return kSCPropNetProxiesFTPProxy;
    } elif index == 10 {
        return kSCPropNetProxiesFTPPort;
    } elif index == 11 {
        return kSCPropNetProxiesGopherEnable;
    } elif index == 12 {
        return kSCPropNetProxiesGopherProxy;
    } elif index == 13 {
        return kSCPropNetProxiesGopherPort;
    } elif index == 14 {
        return kSCPropNetProxiesSOCKSEnable;
    } elif index == 15 {
        return kSCPropNetProxiesSOCKSProxy;
    }
    return kSCPropNetProxiesSOCKSPort;
}

impl cf_release(cf: ptr) {
    CFRelease(cf);
}

impl cf_dictionary_value(dct: ptr, key: ptr) -> ptr {
    return CFDictionaryGetValue(dct, key);
}

impl cf_number_int32(num: ptr) -> i32 {
    result = ptr[i32](__thread_local_block("jac_scproxy_number", 4));
    result.view(1)[0] = 0;
    CFNumberGetValue(num, 3, ptr(result));
    return result.view(1)[0];
}

impl cf_string_utf8_pointer(ref: ptr, encoding: u32) -> ptr[u8] {
    return CFStringGetCStringPtr(ref, encoding);
}

impl cf_string_length(ref: ptr) -> i64 {
    return CFStringGetLength(ref);
}

impl cf_string_copy(ref: ptr, buf: ptr[u8], size: i64, encoding: u32) -> bool {
    return CFStringGetCString(ref, buf, size, encoding) != 0;
}

impl cf_array_count(array: ptr) -> i64 {
    return CFArrayGetCount(array);
}

impl cf_array_value(array: ptr, index: i64) -> ptr {
    return CFArrayGetValueAtIndex(array, index);
}
