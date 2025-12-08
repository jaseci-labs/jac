# Fixture 06: Package __init__.jac re-exports
# main.jac - import from package using __init__.jac aggregated exports

# Import from package level - symbols re-exported via __init__.jac
import from mylib {
    CORE_VALUE,
    core_function,
    UTIL_VALUE,
    PACKAGE_VERSION
}

with entry {
    print(f"Package module import - CORE_VALUE: {CORE_VALUE}");
    print(f"Package module import - core_function(): {core_function()}");
    print(f"Package module import - UTIL_VALUE: {UTIL_VALUE}");
}
