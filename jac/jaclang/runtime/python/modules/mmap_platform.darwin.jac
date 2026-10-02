"""Memory-mapping facilities of macOS: no mremap(), and a full fsync before mapping a file.

mmap.resize() reports that resizing is unavailable here; the mremap
stand-in keeps the portable module typed and is never called.
"""

glob HAS_MREMAP: bool = False,
     FULLFSYNC_BEFORE_MAP: bool = True,
     REFUSES_SHARED_ANONYMOUS_GROWTH: bool = False;

def mremap(old_address: ptr, old_size: u64, new_size: u64, flags: i32) -> ptr {
    return ptr();
}
