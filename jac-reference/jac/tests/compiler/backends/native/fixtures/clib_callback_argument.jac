"""A direct C callback argument needs the same ABI adaptation as a vtable."""
import from c {
    def clib_invoke_i32(callback: Callable[[i32], i32], value: i32) -> i32;
}

def signed_value(value: int) -> int {
    return 123 if value < 0 else 456;
}

def call_signed -> i32 {
    return clib_invoke_i32(signed_value, i32(-5));
}
