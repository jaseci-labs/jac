"""Test fixture for JavaScript export semantics with :pub annotations."""

cl {

# Public class - should generate: export class PublicClass { }
obj :pub PublicClass {
    has value: int = 0;

    def get_value -> int {
        return self.value;
    }
}

# Private class (no :pub) - should NOT generate export
obj PrivateClass {
    has data: str = "private";
}

# Public function - should generate: export function publicFunction() { }
def :pub public_function(x: int) -> int {
    return x * 2;
}

# Private function (no :pub) - should NOT generate export
def private_function(y: int) -> int {
    return y + 1;
}

# Public enum - should generate: export const PublicStatus = { ... }
enum :pub PublicStatus {
    ACTIVE = "active",
    INACTIVE = "inactive"
}

# Private enum (no :pub) - should NOT generate export
enum PrivateStatus {
    ON = 1,
    OFF = 0
}

}
