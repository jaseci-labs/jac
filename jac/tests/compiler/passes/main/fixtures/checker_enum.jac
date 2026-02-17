"""Tests for enum type checking."""
import from enum { IntEnum, IntFlag }

enum Color { RED = 1, GREEN = 2, BLUE = 3 }
enum Status { PENDING = "pending", ACTIVE = "active" }
enum AutoValueTest { FIRST, SECOND = 10, THIRD }
enum BaseEnum ( IntEnum ) { BASE = 100 }
enum DerivedEnum ( BaseEnum ) {
    A = 1,
    B = "jac"
}  # Error: IntEnum requires int values, got str


enum Permission ( IntFlag ) { READ = 1, WRITE = 2, EXECUTE = 4 }

enum ShapeType;
impl ShapeType{
    CIRCLE = "circle",
    SQUARE = "square"
}

glob name_ok: str = Color.RED.name,
     name_err: int = Color.RED.name,  # Error: str assigned to int
     value_ok: int = Color.BLUE.value,
     value_err: str = Color.BLUE.value,  # Error: int assigned to str
     value_status_ok: str = Status.PENDING.value,
     value_status_val_err: int = Status.ACTIVE.value,  # Error: str assigned to int
     auto_val_ok: int = AutoValueTest.FIRST.value,
     auto_val_err: str = AutoValueTest.THIRD.value,  # Error: int assigned to str
     flag_perm: Permission = Permission.READ,
     flag_val: int = flag_perm.value,
     flag_combined: int = Permission.READ.value | Permission.WRITE.value,
     impl_shape_ok: str = ShapeType.SQUARE.name,
     impl_shape_name_err: int = ShapeType.SQUARE.name,  # Error: str assigned to int
     func_ok: str = process_color(Color.BLUE),
     func_wrong_type: str = process_color("not a color");  # Error: str not Color

def process_color(c: Color) -> str {
    return c.name;
}
