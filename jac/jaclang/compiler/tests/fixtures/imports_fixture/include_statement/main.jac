# Fixture 03: From-import star (2 files)
# main.jac - uses 'import from X { * }' syntax

# import from module_c { * }
include module_c;

with entry {
    print(f"Star import - PUBLIC_VAR: {PUBLIC_VAR}");
    print(f"Star import - public_func(): {public_func()}");
}
