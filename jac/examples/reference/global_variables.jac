"""Global variables: Module-level variables with let and glob keywords."""

# Let with access modifiers
let:priv private_val = 5;
let:pub public_val = 10;

# Glob with access modifiers
glob:protect protected_var = 15;
glob shared_var = 20;

# Multiple variable declarations
glob x = 1, y = 2, z = 3;

# Typed global
glob counter: int = 0;

with entry {
    print(private_val, public_val, protected_var, shared_var, x, y, z, counter);
}
