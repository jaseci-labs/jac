"""Variables named like functions of a module this one imports from.

Only `other` and `named` are imported; `burst`, `shared`, `spark`, `flare` and
`ember` are this module's own entry variable, globals and locals.
"""
import from var_shadows_function_lib { other, named }

obj Thing {
    has value: int = 7;

    def doubled -> int {
        return self.value * 2;
    }
}

glob shared: Thing = Thing(value=3),
     spark = lambda (x: int) -> int { return x + 100; };

def total(item: Thing) -> int {
    return item.value + 1;
}

def glob_read_probe -> int {
    return shared.value * 100 + shared.doubled() * 10 + total(shared);
}

def local_read_probe -> int {
    flare = Thing(value=5);
    return flare.value * 100 + flare.doubled() * 10 + total(flare);
}

def local_call_probe -> int {
    ember = lambda (x: int) -> int { return x + 100; };
    return ember(1);
}

def param_probe(burst: Thing) -> int {
    return burst.value;
}

def param_caller_probe -> int {
    return param_probe(Thing(value=11));
}

def imported_probe -> int {
    held = named;
    return other(1) * 1000 + named(2) + held(3);
}

with entry {
    print(other(1));
    burst = Thing();
    burst.value = 9;
    print(burst.value, burst.doubled(), total(burst));
    print(spark(1));
    print(glob_read_probe(), local_read_probe(), local_call_probe());
    print(param_caller_probe(), imported_probe());
}
