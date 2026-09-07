import math as arithmetic;
import bare_import_helper as helper;

obj LocalMath {
    has pi: int = 12;

    def sqrt(value: float) -> float {
        return value + 1.0;
    }
}

def use_local_math(math: LocalMath) -> int {
    return int(math.sqrt(8.0)) + math.pi;
}

def standard_module_shadow_probe -> int {
    return use_local_math(LocalMath());
}

def canonical_module_name_shadow_probe -> int {
    bare_import_helper = 1;
    return helper.COUNT + bare_import_helper;
}
