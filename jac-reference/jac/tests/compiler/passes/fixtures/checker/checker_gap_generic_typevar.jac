"""Gap #38: Generic TypeVar binding is incomplete.

When a generic class is instantiated with concrete type arguments
(e.g., Box[int]), TypeVar T should be resolved to int throughout.
Method return types containing T should return int. Method parameters
typed as T should only accept int. Currently TypeVars are not
fully substituted, so type errors in generic usage are missed.

Expected errors:
  1. Box[int].get() returns int, not assignable to str
  2. Box[int].set_("hello") — str not assignable to T=int param
  3. Pair[str, int].first() returns str, not assignable to int
  4. Pair[str, int].second() returns int, not assignable to str
  5. Stack[float].push("pi") — str not assignable to T=float param
  6. Stack[float].peek() returns float, not assignable to str
  7. Box[list[int]].get() returns list[int], not list[str]
"""

# Single TypeVar
obj Box[T] {
    has value: T;

    def get -> T {
        return self.value;
    }

    def set_(new_val: T) -> None {
        self.value = new_val;
    }
}

# Two TypeVars
obj Pair[A, B] {
    has first_val: A,
        second_val: B;

    def first -> A { return self.first_val; }
    def second -> B { return self.second_val; }
}

# Generic with internal state
obj Stack[T] {
    has items: list[T] = [];

    def push(item: T) -> None {
        self.items.append(item);
    }

    def pop -> T {
        return self.items.pop();
    }

    def peek -> T {
        return self.items[-1];
    }

    def size -> int {
        return len(self.items);
    }
}

with entry {
    # --- Box[int] ---
    b = Box[int](value=42);

    ok1: int = b.get();         # Ok: T=int -> int
    bad1: str = b.get();        # Error: int -> str

    b.set_(10);                 # Ok: int -> T=int
    b.set_("hello");            # Error: str -> T=int param

    # --- Pair[str, int] ---
    p = Pair[str, int](first_val="hello", second_val=42);

    ok2: str = p.first();       # Ok: A=str -> str
    bad3: int = p.first();      # Error: str -> int

    ok3: int = p.second();      # Ok: B=int -> int
    bad4: str = p.second();     # Error: int -> str

    # --- Stack[float] ---
    s = Stack[float]();
    s.push(3.14);               # Ok: float -> T=float
    s.push("pi");               # Error: str -> T=float param

    ok4: float = s.peek();      # Ok: T=float -> float
    bad5: str = s.peek();       # Error: float -> str

    ok5: int = s.size();        # Ok: int -> int (non-generic method)

    # --- Nested generics ---
    nested = Box[list[int]](value=[1, 2, 3]);
    ok6: list[int] = nested.get();     # Ok
    bad6: list[str] = nested.get();    # Error: list[int] -> list[str]
}
