"""Global variables: Module-level variables with keyword."""

# Glob with access modifiers
glob:priv private_val = 5;
glob:pub public_val = 10;

# Glob with access modifiers
glob:protect protected_var = 15;
glob shared_var = 20,
     x = 1,
     y = 2,
     z = 3,
     counter: int = 0;

with entry {
    print(private_val, public_val, protected_var, shared_var, x, y, z, counter);
}
# Multiple variable declarations

# Typed global
