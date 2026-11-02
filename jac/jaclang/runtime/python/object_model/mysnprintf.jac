import from c {
    def vsnprintf(buf: ptr[u8], size: u64, format: ptr[u8], va: ptr) -> i32;  def PyOS_snprintf(
        buf: ptr[u8], size: u64, format: ptr[u8], *args: VaList
    ) -> i32 {
        return PyOS_vsnprintf(buf, size, format, ptr(args));
    }  def PyOS_vsnprintf(buf: ptr[u8], size: u64, format: ptr[u8], va: ptr) -> i32 {
        length: i32 = 0;
        if size > u64(INT_MAX - 1) {
            length = -666;
        } else {
            length = vsnprintf(buf, size, format, va);
        }
        if size > u64(0) {
            (buf + i64(size - u64(1))).view(1)[0] = u8(0);
        }
        return length;
    }
}

glob:priv INT_MAX: Final[i64] = 2147483647;
