"""Own an exported Python buffer across conversions that can invoke user code."""
import from c {
    def jacpy_buffer_acquire(value: u64, ascii: i64) -> u64;  def jacpy_buffer_release(
        value: u64
    );  def jacpy_buffer_bytes(view: u64) -> u64;  def jacpy_buffer_address(
        view: u64
    ) -> u64;  def jacpy_buffer_length(view: u64) -> i64;  def jacpy_buffer_dimensions(
        view: u64
    ) -> i64;
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

    def address -> u64 {
        return jacpy_buffer_address(self.view);
    }

    def size -> i64 {
        return jacpy_buffer_length(self.view);
    }

    def dimensions -> i64 {
        return jacpy_buffer_dimensions(self.view);
    }

    def drop {
        jacpy_buffer_release(self.view);
    }
}
