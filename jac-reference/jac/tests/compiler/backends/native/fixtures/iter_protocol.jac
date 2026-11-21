# Native fixture: first-class iterator values via iter() / next() and
# for-loop driving of a stored iterator (#6403 phase 2 + M1).

def double(x: int) -> int {
    return x * 2;
}

# --- iter() / next() over a list ---
# iter() + next(): explicit pull. a=5, b=7 -> 57
def iter_next_basic -> int {
    it = iter([5, 7, 9]);
    a = next(it);
    b = next(it);
    return a * 10 + b;
}

# for-loop over a stored iterator value: 1+2+3+4 = 10
def for_over_iter -> int {
    it = iter([1, 2, 3, 4]);
    total: int = 0;
    for x in it {
        total = total + x;
    }
    return total;
}

# iter() over a string, next() yields single-char strings; count first two.
# 'h','i' -> both length 1 -> 1 + 1 = 2
def str_iter_next -> int {
    it = iter("hi");
    a = next(it);
    b = next(it);
    return len(a) + len(b);
}

# --- M1: iter() over range / dict / set ---
# iter(range(5)) driven via a for-loop: 0+1+2+3+4 = 10
def for_over_range_iter -> int {
    it = iter(range(5));
    total = 0;
    for x in it {
        total = total + x;
    }
    return total;
}

# next() over a stepped, offset range. range(10,20,3) -> 10,13,16,19.
# a=10, b=13 -> 1013
def next_range -> int {
    it = iter(range(10, 20, 3));
    a = next(it);
    b = next(it);
    return a * 100 + b;
}

# descending range(5,0,-1) -> 5,4,3,2,1 -> 15
def for_over_range_desc -> int {
    it = iter(range(5, 0, -1));
    total = 0;
    for x in it {
        total = total + x;
    }
    return total;
}

# iter(dict) yields keys (insertion order). keys 1,2 -> 3
def for_over_dict_iter -> int {
    m: dict[int, int] = {1: 10, 2: 20};
    it = iter(m);
    s = 0;
    for k in it {
        s = s + k;
    }
    return s;
}

# iter(set) yields each element once. {3,4,5} -> 12
def for_over_set_iter -> int {
    st: set[int] = {3, 4, 5};
    it = iter(st);
    s = 0;
    for x in it {
        s = s + x;
    }
    return s;
}

# --- composition: adapter over a stored iterator ---
# map(double, it) over a stored list iterator: (1+2+3)*2 = 12
def map_over_stored -> int {
    it = iter([1, 2, 3]);
    total = 0;
    for x in map(double, it) {
        total = total + x;
    }
    return total;
}

# `iter()` of a stored iterator is a no-op (Python's `iter(it) is it`). The loop
# borrows the same JacIter the variable owns, so the source's single +1 must be
# retained for the loop's owned reference — otherwise it is released twice (loop
# end + scope exit), a use-after-free. 1+2+3+4 = 10. (#6403)
def for_over_iter_of_stored -> int {
    it = iter([1, 2, 3, 4]);
    total: int = 0;
    for x in iter(it) {
        total = total + x;
    }
    return total;
}

# Same alias as a stored binding: `it2 = iter(it)` makes it2 own its own +1
# (a retain), so both it and it2 release once each at scope exit. 1+2+3+4 = 10.
def assign_iter_of_stored -> int {
    it = iter([1, 2, 3, 4]);
    it2 = iter(it);
    total: int = 0;
    for x in it2 {
        total = total + x;
    }
    return total;
}

# next() exhaustion raises StopIteration (caught -> 99).
def next_exhausted -> int {
    it = iter([1]);
    a = next(it);
    try {
        b = next(it);
        return a + b;
    } except Exception {
        return 99;
    }
}

def iterator_list_values -> int {
    numbers = iter([2, 5, 9]);
    first = next(numbers);
    remaining = list(numbers);
    exhausted = list(numbers);
    words = list(iter(["ab", "cde"]));
    floats = list(iter([1.5, 2.5]));
    return first
        + remaining[0]
        + remaining[1]
        + len(exhausted)
        + len(words[0])
        + len(words[1])
        + int(floats[0] + floats[1]);
}

glob iter_items_dropped: int = 0;

obj IterItem {
    has value: int;

    def drop {
        iter_items_dropped += 1;
    }
}

def iterator_item_drop_count -> int {
    return iter_items_dropped;
}

def local_object_iterator -> Iterator[IterItem] {
    values = [IterItem(17), IterItem(29)];
    return iter(values);
}

def local_dict_iterator -> Iterator[str] {
    values = {"alpha": 1, "beta": 2};
    return iter(values);
}

def local_set_iterator -> Iterator[int] {
    values = {3, 7};
    return iter(values);
}

def local_string_iterator -> Iterator[str] {
    text = "".join(["ab", "cd"]);
    return iter(text);
}

def local_bytes_iterator -> Iterator[int] {
    data = b"abc" + b"def";
    return iter(data);
}

def returned_iterator_values -> int {
    objects = list(local_object_iterator());
    keys = list(local_dict_iterator());
    numbers = list(local_set_iterator());
    letters = list(local_string_iterator());
    octets = list(local_bytes_iterator());
    return objects[0].value
        + objects[1].value
        + len(keys[0])
        + len(keys[1])
        + numbers[0]
        + numbers[1]
        + len(letters)
        + octets[0]
        + octets[5];
}
