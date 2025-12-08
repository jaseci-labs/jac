# mypackage/__init__.jac
# Package initialization file - re-exports from submodules
# When you import from a package, __init__.jac defines what's available
import from .helper {
    HELPER_VALUE,
    helper_func
}
