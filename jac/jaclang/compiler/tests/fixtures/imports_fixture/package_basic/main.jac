# Fixture 05: Package with __init__.jac
# main.jac - imports from a package using __init__.jac

# Direct import from package (uses __init__.jac re-exports)
import from mypackage {
    HELPER_VALUE,
    helper_func
}

with entry {
    print(f"Package from-import - HELPER_VALUE: {HELPER_VALUE}");
    print(f"Package from-import - helper_func(): {helper_func()}");
}
