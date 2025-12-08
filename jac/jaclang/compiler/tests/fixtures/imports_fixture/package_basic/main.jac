import from mypackage { HELPER_VALUE, helper_func }

with entry {
    print(f"Package from-import - HELPER_VALUE: {HELPER_VALUE}");
    print(f"Package from-import - helper_func(): {helper_func()}");
}
