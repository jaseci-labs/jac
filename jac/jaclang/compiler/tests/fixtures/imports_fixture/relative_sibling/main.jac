# Fixture 07: Relative imports within package
# main.jac - runs the package with relative imports
import from pkg.sibling {
    SIBLING_VALUE,
    sibling_func
}
import from pkg.base { BASE_VALUE }

with entry {
    print(f"Relative import - BASE_VALUE: {BASE_VALUE}");
    print(f"Relative import - SIBLING_VALUE: {SIBLING_VALUE}");
    print(f"Relative import - sibling_func(): {sibling_func()}");
}
