"""Generic[T] and TypeVar annotation support.

Tests Generic classes with explicit TypeVar declarations, ensuring
type parameter constraints and variance work correctly.
"""
import from typing { Generic, TypeVar, Optional }

# Simple TypeVar
T = TypeVar('T');
U = TypeVar('U');

# TypeVar with constraints
NumberT = TypeVar('NumberT', int, float, bound=None);
SequenceT = TypeVar('SequenceT');

# Generic container class
obj Box[T] {
    has value: T;

    def get() -> T {
        return self.value;
    }

    def set(v: T) -> None {
        self.value = v;
        return;
    }

    def map[U](f: Callable[[T], U]) -> Box[U] {
        return Box(value=f(self.value));
    }
}

# --- Valid: Generic instantiation ---
def ok_generic_int() -> int {
    box: Box[int] = Box(value=42);
    return box.get();
}

def ok_generic_str() -> str {
    box: Box[str] = Box(value="hello");
    return box.get();
}

def ok_generic_nested() -> Box[list[str]] {
    box: Box[list[str]] = Box(value=["a", "b"]);
    return box;
}

# --- Valid: Type parameter inference in assignment ---
def ok_inferred_int() -> int {
    box = Box(value=42);  # Type inferred as Box[int]
    return box.get();
}

def ok_inferred_str() -> str {
    box = Box(value="test");  # Type inferred as Box[str]
    return box.get();
}

# --- Valid: Generic method call ---
def ok_map_transform() -> Box[str] {
    box: Box[int] = Box(value=42);
    # map should infer U=str when f returns str
    return box.map(lambda x: str(x));
}

# --- Valid: Polymorphic parameter ---
def process_any_box[T](b: Box[T]) -> T {
    return b.get();
}

def ok_polymorphic() -> str {
    box: Box[str] = Box(value="hello");
    return process_any_box(box);
}

# --- Invalid: Type mismatch in set ---
def bad_set_wrong_type() -> None {
    box: Box[int] = Box(value=42);
    box.set("string");  # Should fail: string is not int
    return;
}

# --- Invalid: Assignment type mismatch ---
def bad_assign_wrong_generic() -> None {
    box_int: Box[int] = Box(value=42);
    box_str: Box[str] = box_int;  # Box[int] cannot be Box[str]
    return;
}

# --- Invalid: Generic parameter mismatch in call ---
def bad_polymorphic_call() -> None {
    box: Box[int] = Box(value=42);
    result: str = process_any_box(box);  # Box[int] -> int, not str
    return;
}
