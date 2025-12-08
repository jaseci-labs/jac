# mylib/__init__.jac
# Package initialization file with selective re-exports
# This allows `import from mylib { CORE_VALUE }` instead of `import from mylib.core { CORE_VALUE }`
import from .core {
    CORE_VALUE,
    core_function
}
import from .utils { UTIL_VALUE, util_function }

# Package-level constant
glob PACKAGE_VERSION = "1.0.0";
