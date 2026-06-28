"""Native __str__ dispatch (#7003): str(obj)/print(obj)/f"{obj}" must call the
user object's __str__, fall back to a `<TypeName object at 0x...>` default when
none is defined, and resolve the runtime subclass through the vtable.
"""

obj P {
    has v: str;

    def __str__ -> str {
        return self.v;
    }
}

obj Q {
    has n: int;
    # __str__ that itself builds a string (nested f-string).
    def __str__ -> str {
        return f"Q({self.n})";
    }
}

# No __str__ anywhere -> sensible default repr, not a garbage pointer.
obj Plain {
    has x: int;
}

# Polymorphism: a base-typed receiver must resolve the runtime subclass's
# __str__ through the vtable (mirrors the class_name.na.jac dispatch shape).
obj Animal {
    has name: str;

    def __str__ -> str {
        return f"Animal:{self.name}";
    }
}

obj Dog(Animal) {
    def __str__ -> str {
        return f"Dog:{self.name}";
    }
}

def obj_str -> str {
    p = P(v="hello");
    return str(p);
}

def obj_str_computed -> str {
    q = Q(n=42);
    return str(q);
}

def obj_in_fstring -> str {
    p = P(v="world");
    return f"[{p}]";
}

def obj_default_repr -> str {
    return str(Plain(x=7));
}

# `a` is statically Animal; str() lowers a virtual __str__ call.
def animal_str(a: Animal) -> str {
    return str(a);
}

def poly_str -> str {
    return animal_str(Dog(name="rex"));
}

def base_str -> str {
    return animal_str(Animal(name="generic"));
}

# A `P | None` value that is None lowers to a null struct pointer; str() must
# render "None" rather than dereference it (vtable GEP) and crash.
def maybe_str(flag: int) -> str {
    p: P | None = None;
    if flag {
        p = P(v="set");
    }
    return str(p);
}

with entry {
    print(P(v="printed"));
}
