# Fixture 01: Simple absolute import (2 files)
# module_a.jac - the module to be imported

glob VALUE_A = "Hello from module_a";

def greet -> str {
    return "Greet from module_a";
}
