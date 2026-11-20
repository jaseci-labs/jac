"""A callback argument of a C function pointer read from a record needs the
C-ABI adaptation a direct C call gives it."""
import from c {
    obj Invoker {
        has invoke: Callable[[Callable[[i32], i32], i32], i32] = 0;
    }
}

def signed_value(value: int) -> int {
    return 123 if value < 0 else 456;
}

def call_through_record(address: int) -> i32 {
    invoker = Invoker();
    invoker.invoke = address;
    return invoker.invoke(signed_value, i32(-5));
}
