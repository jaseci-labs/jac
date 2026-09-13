"""Own an exported Python buffer across conversions that can invoke user code."""
import from c {
    def jacpy_buffer_acquire(value: u64, ascii: i64) -> u64;  def jacpy_buffer_release(
        value: u64
    );  def jacpy_buffer_bytes(view: u64) -> u64;
}

obj BufferArgument {
    has view: u64 = 0;

    def acquire(value: u64, ascii: bool = False) -> bool {
        jacpy_buffer_release(self.view);
        self.view = jacpy_buffer_acquire(value, i64(ascii));
        return self.view != 0;
    }

    def bytes -> u64 {
        return jacpy_buffer_bytes(self.view);
    }

    def drop {
        jacpy_buffer_release(self.view);
    }
}
