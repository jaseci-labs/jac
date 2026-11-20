import from lazy_decl_lib { wide_3, wide_7, wide_11 }
import lazy_decl_lib;

def used_bare(n: int) -> int {
    return wide_3(n) + wide_7(n);
}

def used_qualified(n: int) -> int {
    return lazy_decl_lib.wide_19(n);
}

def nested_use(n: int) -> int {
    def inner(m: int) -> int {
        return wide_7(m) + 1;
    }
    return inner(n);
}
