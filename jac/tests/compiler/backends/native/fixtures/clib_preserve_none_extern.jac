"""A preserve_none handler that tail-calls handlers C defines, the way an
instruction handler jumps to an interpreter label CPython still owns."""
import from c {
    @__preserve_none
    def c_handler(frame: ptr[u8], sp: ptr[u64], arg: i32) -> ptr[u8];  @__preserve_none
    def jac_handler(frame: ptr[u8], sp: ptr[u64], arg: i32) -> ptr[u8] {
        if arg == 0 {
            return tail c_handler(frame, sp - 1, arg);
        }
        return tail c_handler(frame, sp, arg - 1);
    }
}
