from __future__ import annotations
from enum import Enum, auto
from jaclang.lib import (
    Node,
    OPath,
    Root,
    Walker,
    build_edge,
    connect,
    field,
    on_entry,
    on_exit,
    refs,
    root,
    spawn,
    visit,
)
from enum import unique


class Color(Enum):
    RED = 1
    GREEN = 2
    BLUE = 3


class Role(Enum):
    ADMIN = "admin"
    USER = "user"
    GUEST = "guest"


print("=== 1. Basic Enums (Integer & String Values) ===")
print(f"  Color.RED: {Color.RED.value}, Role.ADMIN: {Role.ADMIN.value}")


@unique
class Priority(Enum):
    LOW = 1
    MEDIUM = 2
    HIGH = 3


print("\n=== 2. Forward Declaration with @unique Decorator ===")
print(f"  Priority.HIGH: {Priority.HIGH.value}")


class Permission(Enum):
    READ = "read"
    WRITE = "write"
    EXECUTE = "execute"


print("\n=== 3. Enum with Access Modifier ===")
print(f"  Permission.WRITE: {Permission.WRITE.value}")


class HttpStatus(Enum):
    OK = 200
    BAD_REQUEST = 400
    SERVER_ERROR = 500

    def is_success(self):
        return 200 <= self.value < 300

    def get_category(self):
        if self.value < 300:
            return "success"
        elif self.value < 500:
            return "client_error"
        return "server_error"


print("\n=== 4. Enum with Python Code Block (Methods) ===")
print(
    f"  {HttpStatus.OK.name}: {HttpStatus.OK.get_category()}, is_success: {HttpStatus.OK.is_success()}"
)
print(f"  {HttpStatus.BAD_REQUEST.name}: {HttpStatus.BAD_REQUEST.get_category()}")


class Status(Enum):
    PENDING = 0
    ACTIVE = 1
    INACTIVE = 2


def get_status_message(status: Status) -> str:
    if status == Status.PENDING:
        return "Waiting for approval"
    elif status == Status.ACTIVE:
        return "Currently active"
    else:
        return "No longer active"


print("\n=== 5. Enum Comparison and Type Safety ===")
s1 = Status.ACTIVE
s2 = Status.ACTIVE
print(f"  Status.ACTIVE == Status.ACTIVE: {s1 == s2}")
print(f"  Status message: {get_status_message(Status.PENDING)}")
print("\n=== 6. Enum Iteration and Lookup ===")
print("  Iterating Priority:")
for p in Priority:
    print(f"    {p.name} = {p.value}")
print(f"  Color(2): {Color(2).name}, Role['ADMIN']: {Role['ADMIN'].value}")
print("\n=== 7. Enum in Data Structures ===")
colors = [Color.RED, Color.GREEN, Color.BLUE]
print(f"  List: {[c.name for c in colors]}")
role_perms = {Role.ADMIN: "Full", Role.USER: "Limited", Role.GUEST: "Read"}
for item in role_perms.items():
    print(f"  Dict: {item[0].name} = {item[1]}")


class Task(Node):
    title: str = "Task"
    priority: Priority = field(factory=lambda: Priority.MEDIUM)
    status: Status = field(factory=lambda: Status.PENDING)


print("\n=== 8. Enum in Node Attributes (OSP) ===")
task = Task(title="Build feature", priority=Priority.HIGH, status=Status.ACTIVE)
print(f"  Task: {task.title}")
print(f"  Priority: {task.priority.name} ({task.priority.value})")
print(f"  Status: {task.status.name}")


class TaskFilter(Walker):
    target_priority: Priority = field(factory=lambda: Priority.HIGH)
    matched: list = field(factory=lambda: [])

    @on_entry
    def traverse(self, here: Root) -> None:
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def filter(self, here: Task) -> None:
        print(f"    Checking task: {here.title}, priority={here.priority.name}")
        if here.priority == self.target_priority:
            self.matched.append(here.title)
            print("      Matched!")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_exit
    def make_report(self, here) -> None:
        print(f"  Found {len(self.matched)} tasks: {self.matched}")


print("\n=== 9. Enum in Walker Logic (OSP) ===")
task1 = Task(title="Critical Bug", priority=Priority.HIGH)
task2 = Task(title="Documentation", priority=Priority.LOW)
task3 = Task(title="Security Patch", priority=Priority.HIGH)
connect(left=root(), right=task1)
connect(left=root(), right=task2)
connect(left=root(), right=task3)
spawn(root(), TaskFilter(target_priority=Priority.HIGH))
print("\n✓ Enumerations demonstrated!")
