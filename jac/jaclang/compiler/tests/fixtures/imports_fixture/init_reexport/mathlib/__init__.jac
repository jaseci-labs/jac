# mathlib/__init__.jac
# Re-exports from submodules to provide a clean public API
# Users can import from mathlib without knowing internal module structure

# Re-export arithmetic operations from operations module
import from .operations {
    add,
    subtract,
    multiply,
    divide
}

# Re-export constants from constants module
import from .constants {
    PI,
    E,
    GOLDEN_RATIO
}

# Re-export calculator class from calculator module
import from .calculator {
    Calculator
}
