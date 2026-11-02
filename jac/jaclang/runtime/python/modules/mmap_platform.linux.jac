"""Memory-mapping facilities of Linux: mremap(), which cannot grow a shared anonymous mapping."""
import from c {
    def mremap(
        old_address: ptr, old_size: u64, new_size: u64, flags: i32, *args: any
    ) -> ptr;
}

glob HAS_MREMAP: bool = True,
     FULLFSYNC_BEFORE_MAP: bool = False,
     REFUSES_SHARED_ANONYMOUS_GROWTH: bool = True;
