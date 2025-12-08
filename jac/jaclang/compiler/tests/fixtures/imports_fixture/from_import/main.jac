# Fixture 02: Simple from-import (2 files)
# main.jac - uses 'import from X { Y }' syntax

import from module_b { VALUE_B, calculate, MyClass }

with entry {
    print(f"From-import - VALUE_B: {VALUE_B}");
    print(f"From-import - calculate(5): {calculate(5)}");
    obj_instance = MyClass();
    print(f"From-import - MyClass: {obj_instance.name}");
}
