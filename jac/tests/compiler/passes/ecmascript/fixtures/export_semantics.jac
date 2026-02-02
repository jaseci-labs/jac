"""Test fixture for JavaScript export semantics with :pub annotations."""

cl {
    # Public items - should be in final export { ... } statement
    glob : pub PUBLIC_API_URL: str = "https://api.example.com";

    obj : pub PublicClass {
        has value: int = 0;
        def get_value -> int {
            return self.value;
        }
    }

    def : pub public_function(x: int) -> int {
        return x * 2;
    }

    enum : pub PublicStatus { ACTIVE = "active", INACTIVE = "inactive" }

    # Private items - should NOT be in export statement
    glob PRIVATE_SECRET: str = "secret123";

    obj PrivateClass {
        has data: str = "private";
    }

    def private_function(y: int) -> int {
        return y + 1;
    }

    enum PrivateStatus { ON = 1, OFF = 0 }
}
