# Fixture 07: sibling.jac - uses relative import from same level
import from .base {
    BASE_VALUE,
    base_func
}

glob SIBLING_VALUE = f"Sibling uses {BASE_VALUE}";

def sibling_func -> str {
    return f"Sibling calls: {base_func()}";
}
