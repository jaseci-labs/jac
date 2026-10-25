import from c { def dladdr(address: ptr, info: ptr) -> i32;  }

def symbol_info(address: ptr, info: ptr[u8], scratch: ptr[u8]) -> i32;

impl symbol_info(address: ptr, info: ptr[u8], scratch: ptr[u8]) -> i32 {
    return dladdr(address, ptr(info));
}
