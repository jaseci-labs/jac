"""Memory-mapping facilities of Linux: mremap(), which cannot grow a shared anonymous mapping."""
import from c {
    # mremap() is variadic, but reads its fifth argument only for
    # MREMAP_FIXED, and Linux passes the fixed arguments alike either way.
    def mremap(old_address: ptr, old_size: u64, new_size: u64, flags: i32) -> ptr;
}

glob HAS_MREMAP: bool = True,
     FULLFSYNC_BEFORE_MAP: bool = False,
     REFUSES_SHARED_ANONYMOUS_GROWTH: bool = True;
