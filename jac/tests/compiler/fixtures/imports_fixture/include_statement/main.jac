include module_c;

with entry {
    print(f"Star import - PUBLIC_VAR: {PUBLIC_VAR}");
    print(f"Star import - public_func(): {public_func()}");
}
