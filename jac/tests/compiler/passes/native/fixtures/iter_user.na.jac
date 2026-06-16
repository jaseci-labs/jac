# Native fixture: user-defined iterator protocol (#6403 M2).
#
# A user `obj` that implements `__iter__`/`__next__` is bridged into the same
# boxed JacIter the builtin iterators use: a per-element call to the user's
# `__next__`, with a StopIteration caught and translated to the iterator
# protocol's `i1 0` exhaustion flag. Bridged user iterators therefore drive
# for-loops, work with first-class iter()/next(), compose under the lazy
# adapters, and cross function boundaries — exactly like a builtin iterator.
# Returns ints so tests can assert via ctypes.
def double(x: int) -> int {
    return x * 2;
}

# A self-iterator: the object is its own iterator (Python's most common idiom,
# `__iter__` returns self).
obj Counter {
    has cur: int;
    has stop: int;

    def __iter__() -> Counter {
        return self;
    }

    def __next__() -> int {
        if self.cur >= self.stop {
            raise StopIteration("done");
        }
        v = self.cur;
        self.cur = self.cur + 1;
        return v;
    }
}

# An iterable whose `__iter__` returns a *separate* fresh iterator object — the
# other standard idiom (a re-iterable collection).
obj Cursor {
    has cur: int;
    has stop: int;

    def __iter__() -> Cursor {
        return self;
    }

    def __next__() -> int {
        if self.cur >= self.stop {
            raise StopIteration("stop");
        }
        v = self.cur;
        self.cur = self.cur + 1;
        return v;
    }
}

obj NumberRange {
    has n: int;

    def __iter__() -> Cursor {
        return Cursor(cur=0, stop=self.n);
    }
}

# --- for-loop over a self-iterator: 0+1+2+3+4 = 10 ---
def user_self_for() -> int {
    total: int = 0;
    for x in Counter(cur=0, stop=5) {
        total = total + x;
    }
    return total;
}

# --- for-loop over a borrowed self-iterator variable: 0+1+2 = 3 ---
def user_self_for_var() -> int {
    c = Counter(cur=0, stop=3);
    total: int = 0;
    for x in c {
        total = total + x;
    }
    return total;
}

# --- for-loop over an iterable whose __iter__ yields a separate cursor:
#     0+1+2+3 = 6 ---
def user_separate_for() -> int {
    total: int = 0;
    for x in NumberRange(n=4) {
        total = total + x;
    }
    return total;
}

# --- first-class iter()/next() over a user iterator: a=10,b=11 -> 1011 ---
def user_iter_next() -> int {
    it = iter(Counter(cur=10, stop=20));
    a = next(it);
    b = next(it);
    return a * 100 + b;
}

# --- map() over a user iterator (adapter composition): (0+1+2)*2 = 6 ---
def user_map_compose() -> int {
    total: int = 0;
    for x in map(double, Counter(cur=0, stop=3)) {
        total = total + x;
    }
    return total;
}

# --- break mid-iteration over a user iterator: stop at x==3, sum 0+1+2 = 3 ---
def user_break() -> int {
    total: int = 0;
    for x in Counter(cur=0, stop=100) {
        if x == 3 {
            break;
        }
        total = total + x;
    }
    return total;
}

# --- a user iterator boxed as Iterator[T] and returned across a function
#     boundary, then for-looped by the caller: 0+1+2+3+4 = 10 ---
def user_gen() -> Iterator[int] {
    return iter(Counter(cur=0, stop=5));
}

def user_cross_fn() -> int {
    total: int = 0;
    for x in user_gen() {
        total = total + x;
    }
    return total;
}

# A user iterator whose __next__ raises a NON-StopIteration error partway.
obj Boom {
    has n: int;

    def __iter__() -> Boom {
        return self;
    }

    def __next__() -> int {
        if self.n <= 0 {
            raise ValueError("boom");
        }
        self.n = self.n - 1;
        return self.n;
    }
}

# --- a non-StopIteration exception raised inside __next__ must propagate out of
#     the for-loop (not be swallowed as end-of-iteration): caught -> 42 ---
def user_next_propagates() -> int {
    total: int = 0;
    try {
        for x in Boom(n=2) {
            total = total + x;
        }
        return -1;
    } except ValueError {
        return 42;
    }
}

# A subclass that inherits __iter__/__next__ from its base.
obj SubCounter(Counter) {
    has extra: int;
}

# --- a subclass driving inherited __iter__/__next__: 0+1+2+3 = 6. The receiver
#     is coerced to __next__'s declared self type, so an inherited method stays
#     well-typed. ---
def user_inherited_iter() -> int {
    total: int = 0;
    for x in SubCounter(cur=0, stop=4, extra=99) {
        total = total + x;
    }
    return total;
}

with entry { }
