"""Fixture: a C record of raw pointers lent to a C function lives on the
stack, and a named function used as a Callable is one static closure."""

import from c {
    obj PointerSlots {
        has first: ptr[u8] = ptr[u8](),
            second: ptr[u8] = ptr[u8]();
    }  def slot_address(slots: &mut PointerSlots) -> int;
}

def lend_slots -> int {
    slots: own PointerSlots = PointerSlots();
    address = slot_address(&mut slots);
    return address;
}

def make_slots -> own PointerSlots {
    made: own PointerSlots = PointerSlots();
    return made;
}

def rebind_slots -> int {
    slots: own PointerSlots = PointerSlots();
    first = slot_address(&mut slots);
    slots = make_slots();
    second = slot_address(&mut slots);
    return first - second;
}

def twice(value: int) -> int {
    return value * 2;
}

def apply(fn: Callable[[int], int], value: int) -> int {
    return fn(value);
}

def apply_named -> int {
    return apply(twice, 21);
}

with entry {
    print(lend_slots() != 0, rebind_slots() != 0, apply_named());
}
