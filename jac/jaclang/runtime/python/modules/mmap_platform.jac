"""Memory mapping for a target with no mmap_platform.<os>.jac: no mremap(); the module rejects it."""

glob HAS_MREMAP: bool = False,
     FULLFSYNC_BEFORE_MAP: bool = False,
     REFUSES_SHARED_ANONYMOUS_GROWTH: bool = False;

def mremap(old_address: ptr, old_size: u64, new_size: u64, flags: i32) -> ptr {
    return ptr();
}
