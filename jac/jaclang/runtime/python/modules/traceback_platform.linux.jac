import from c {
    def dladdr1(address: ptr, info: ptr, extra_info: ptr, flags: i32) -> i32;
}

glob:priv RTLD_DL_LINKMAP: Final[i32] = 2;

def symbol_info(address: ptr, info: ptr[u8], scratch: ptr[u8]) -> i32;

impl symbol_info(address: ptr, info: ptr[u8], scratch: ptr[u8]) -> i32 {
    map_slot = ptr[ptr[u64]](scratch);
    status = dladdr1(address, ptr(info), ptr(map_slot), RTLD_DL_LINKMAP);
    fname = ptr[ptr[u8]](info).view(1)[0];
    if status != i32(0) and fname and fname.view(1)[0] != u8(0) {
        ptr[u64](info + 8).view(1)[0] = map_slot.view(1)[0].view(1)[0];
    }
    return status;
}
