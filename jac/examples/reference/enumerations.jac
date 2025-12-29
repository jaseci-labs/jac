# Enumerations - Type-safe named constants
import from enum { unique }

# ===== Basic Enums with Integer and String Values =====
enum Color {
    RED = 1,
    GREEN = 2,
    BLUE = 3
}

enum Role {
    ADMIN = 'admin',
    USER = 'user',
    GUEST = 'guest',  # Trailing comma supported
}

with entry {
    print("=== 1. Basic Enums (Integer & String Values) ===");
    print(f"  Color.RED: {Color.RED.value}, Role.ADMIN: {Role.ADMIN.value}");
}

# ===== Forward Declaration with Impl and Decorator =====
@ unique
enum Priority;

impl Priority{
    LOW = 1,
    MEDIUM = 2,
    HIGH = 3
}

with entry {
    print("\n=== 2. Forward Declaration with @unique Decorator ===");
    print(f"  Priority.HIGH: {Priority.HIGH.value}");
}

# ===== Enum with Access Modifier =====
enum : protect Permission {
    READ = 'read',
    WRITE = 'write',
    EXECUTE = 'execute'
}

with entry {
    print("\n=== 3. Enum with Access Modifier ===");
    print(f"  Permission.WRITE: {Permission.WRITE.value}");
}

# ===== Enum with Python Code Block and Methods =====
enum HttpStatus {
    OK = 200,
    BAD_REQUEST = 400,
    SERVER_ERROR = 500::py::
    def is_success(self):
        return 200 <= self.value < 300

    def get_category(self):
        if self.value < 300:
            return "success"
        elif self.value < 500:
            return "client_error"
        return "server_error"
    ::py::

}

with entry {
    print("\n=== 4. Enum with Python Code Block (Methods) ===");
    print(
        f"  {HttpStatus.OK.name}: {HttpStatus.OK.get_category()}, is_success: {HttpStatus.OK.is_success()}"
    );
    print(f"  {HttpStatus.BAD_REQUEST.name}: {HttpStatus.BAD_REQUEST.get_category()}");
}

# ===== Enum Comparison and Functions =====
enum Status {
    PENDING = 0,
    ACTIVE = 1,
    INACTIVE = 2
}

def get_status_message(status: Status) -> str {
    if status == Status.PENDING {
        return "Waiting for approval";
    } elif status == Status.ACTIVE {
        return "Currently active";
    } else {
        return "No longer active";
    }
}

with entry {
    print("\n=== 5. Enum Comparison and Type Safety ===");
}

glob s1 = Status.ACTIVE,
     s2 = Status.ACTIVE;

with entry {
    print(f"  Status.ACTIVE == Status.ACTIVE: {s1 == s2}");
    print(f"  Status message: {get_status_message(Status.PENDING)}");
}

# ===== Enum Iteration and Lookup =====
with entry {
    print("\n=== 6. Enum Iteration and Lookup ===");
    # Iteration
    print("  Iterating Priority:");
    for p in Priority {
        print(f"    {p.name} = {p.value}");
    }
    # Access by value and name
    print(f"  Color(2): {Color(2).name}, Role['ADMIN']: {Role['ADMIN'].value}");
}

# ===== Enum in Data Structures =====
with entry {
    print("\n=== 7. Enum in Data Structures ===");
}

# List and dict with enums
glob colors = [Color.RED, Color.GREEN, Color.BLUE];

with entry {
    print(f"  List: {[c.name for c in colors]}");
}

glob role_perms = {Role.ADMIN: "Full", Role.USER: "Limited", Role.GUEST: "Read"};

with entry {
    for item in role_perms.items() {
        print(f"  Dict: {item[0].name} = {item[1]}");
    }
}

# ===== OSP Integration: Enum in Node Attributes =====
node Task {
    has title: str = "Task",
        priority: Priority = Priority.MEDIUM,
        status: Status = Status.PENDING;
}

with entry {
    print("\n=== 8. Enum in Node Attributes (OSP) ===");
}

glob task = Task(
         title="Build feature", priority=Priority.HIGH, status=Status.ACTIVE
     );

with entry {
    print(f"  Task: {task.title}");
    print(f"  Priority: {task.priority.name} ({task.priority.value})");
    print(f"  Status: {task.status.name}");
}

# ===== OSP Integration: Enum in Walker Logic =====
walker TaskFilter {
    has target_priority: Priority = Priority.HIGH,
        matched: list = [];

    can traverse with `root entry {
        visit [-->];
    }

    can filter with Task entry {
        print(f"    Checking task: {here.title}, priority={here.priority.name}");
        if here.priority == self.target_priority {
            self.matched.append(here.title);
            print(f"      Matched!");
        }
        visit [-->];
    }

    can make_report with exit {
        print(f"  Found {len(self.matched)} tasks: {self.matched}");
    }
}

with entry {
    print("\n=== 9. Enum in Walker Logic (OSP) ===");
}

glob task1 = Task(title="Critical Bug", priority=Priority.HIGH),
     task2 = Task(title="Documentation", priority=Priority.LOW),
     task3 = Task(title="Security Patch", priority=Priority.HIGH);

with entry {
    root ++> task1;
    root ++> task2;
    root ++> task3;

    root spawn TaskFilter(target_priority=Priority.HIGH);
}

with entry {
    print("\n✓ Enumerations demonstrated!");
}
