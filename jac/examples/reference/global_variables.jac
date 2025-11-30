"""Global variables: Module-level variables with let keyword."""

# Let with access modifiers
let : priv private_val = 5;
let : pub public_val = 10;

# Let with access modifiers
let : protect protected_var = 15;
let shared_var = 20;

# Multiple variable declarations
let x = 1 , y = 2 , z = 3;

# Typed global
let counter: int = 0;

with entry {
    print(private_val, public_val, protected_var, shared_var, x, y, z, counter);
}
