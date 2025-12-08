# Fixture 01: Simple absolute import (2 files)
# main.jac - imports module_a using absolute import

import module_a;

with entry {
    print(f"Absolute import - VALUE_A: {module_a.VALUE_A}");
    print(f"Absolute import - greet(): {module_a.greet()}");
}
