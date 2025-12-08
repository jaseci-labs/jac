# mypackage/__init__.jac
# This file makes the directory a Jac package
# Symbols defined/imported here are accessible via `import from mypackage { ... }`

# Define package-level constants
glob PACKAGE_NAME = "MyPackage";
glob PACKAGE_VERSION = "2.0.0";

# Define package-level function
def greet(name: str) -> str {
    return f"Hello, {name} from {PACKAGE_NAME}!";
}

# Define package-level class
obj Helper {
    has version: str = PACKAGE_VERSION;
    
    def get_info -> str {
        return f"{PACKAGE_NAME} v{self.version}";
    }
}
