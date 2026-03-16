"""Entry module for imported-archetype-methods fix test (FIX 3a).

Imports Counter from fix_method_lib and calls its methods.  Before the
fix, method_funcs for imported archetypes was never populated, so all
method calls were silently dropped and results were undefined.
"""

import from fix_method_lib { Counter, make_counter, make_counter_at }

"""Increment once; expect 1."""
def:pub test_increment_once() -> int {
    c: Counter = make_counter();
    return c.increment();
}

"""Increment twice; expect 2."""
def:pub test_increment_twice() -> int {
    c: Counter = make_counter();
    c.increment();
    return c.increment();
}

"""Start at 5, add delta 3; expect 8."""
def:pub test_add_delta() -> int {
    c: Counter = make_counter_at(5);
    return c.add_delta(3);
}

"""Multiple method calls are independent across instances."""
def:pub test_two_counters() -> int {
    a: Counter = make_counter();
    b: Counter = make_counter_at(10);
    a.increment();
    a.increment();   # a.value == 2
    b.add_delta(5);  # b.value == 15
    # encode: a*100 + b
    return a.value * 100 + b.value;
}

with entry {}
