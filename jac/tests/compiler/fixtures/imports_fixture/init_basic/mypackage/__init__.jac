glob PACKAGE_NAME = "MyPackage";
glob PACKAGE_VERSION = "2.0.0";

def greet(name: str) -> str {
    return f"Hello, {name} from {PACKAGE_NAME}!";
}

obj Helper {
    has version: str = PACKAGE_VERSION;

    def get_info -> str {
        return f"{PACKAGE_NAME} v{self.version}";
    }
}
