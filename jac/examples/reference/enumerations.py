from __future__ import annotations
from jaclang.runtimelib.builtin import *
from enum import Enum, auto
from jaclang import JacMachineInterface as _jl
from enum import unique

@_jl.sem('', {'RED': '', 'GREEN': '', 'BLUE': ''})
class Color(Enum):
    RED = 1
    GREEN = 2
    BLUE = 3

@_jl.sem('', {'ADMIN': '', 'USER': '', 'GUEST': ''})
class Role(Enum):
    ADMIN = 'admin'
    USER = 'user'
    GUEST = 'guest'
print('=== 1. Basic Enums (Integer & String Values) ===')
print(f'  Color.RED: {Color.RED.value}, Role.ADMIN: {Role.ADMIN.value}')

@unique
@_jl.sem('', {'LOW': '', 'MEDIUM': '', 'HIGH': ''})
class Priority(Enum):
    LOW = 1
    MEDIUM = 2
    HIGH = 3
print('\n=== 2. Forward Declaration with @unique Decorator ===')
print(f'  Priority.HIGH: {Priority.HIGH.value}')

@_jl.sem('', {'READ': '', 'WRITE': '', 'EXECUTE': ''})
class Permission(Enum):
    READ = 'read'
    WRITE = 'write'
    EXECUTE = 'execute'
print('\n=== 3. Enum with Access Modifier ===')
print(f'  Permission.WRITE: {Permission.WRITE.value}')

@_jl.sem('', {'OK': '', 'BAD_REQUEST': '', 'SERVER_ERROR': ''})
class HttpStatus(Enum):
    OK = 200
    BAD_REQUEST = 400
    SERVER_ERROR = 500

    def is_success(self):
        return 200 <= self.value < 300

    def get_category(self):
        if self.value < 300:
            return 'success'
        elif self.value < 500:
            return 'client_error'
        return 'server_error'
print('\n=== 4. Enum with Python Code Block (Methods) ===')
print(f'  {HttpStatus.OK.name}: {HttpStatus.OK.get_category()}, is_success: {HttpStatus.OK.is_success()}')
print(f'  {HttpStatus.BAD_REQUEST.name}: {HttpStatus.BAD_REQUEST.get_category()}')

@_jl.sem('', {'PENDING': '', 'ACTIVE': '', 'INACTIVE': ''})
class Status(Enum):
    PENDING = 0
    ACTIVE = 1
    INACTIVE = 2

def get_status_message(status: Status) -> str:
    if status == Status.PENDING:
        return 'Waiting for approval'
    elif status == Status.ACTIVE:
        return 'Currently active'
    else:
        return 'No longer active'
print('\n=== 5. Enum Comparison and Type Safety ===')
s1 = Status.ACTIVE
s2 = Status.ACTIVE
print(f'  Status.ACTIVE == Status.ACTIVE: {s1 == s2}')
print(f'  Status message: {get_status_message(Status.PENDING)}')
print('\n=== 6. Enum Iteration and Lookup ===')
print('  Iterating Priority:')
for p in Priority:
    print(f'    {p.name} = {p.value}')
print(f"  Color(2): {Color(2).name}, Role['ADMIN']: {Role['ADMIN'].value}")
print('\n=== 7. Enum in Data Structures ===')
colors = [Color.RED, Color.GREEN, Color.BLUE]
print(f'  List: {[c.name for c in colors]}')
role_perms = {Role.ADMIN: 'Full', Role.USER: 'Limited', Role.GUEST: 'Read'}
for item in role_perms.items():
    print(f'  Dict: {item[0].name} = {item[1]}')

class Task(_jl.Node):
    title: str = 'Task'
    priority: Priority = _jl.field(factory=lambda: Priority.MEDIUM)
    status: Status = _jl.field(factory=lambda: Status.PENDING)
print('\n=== 8. Enum in Node Attributes (OSP) ===')
task = Task(title='Build feature', priority=Priority.HIGH, status=Status.ACTIVE)
print(f'  Task: {task.title}')
print(f'  Priority: {task.priority.name} ({task.priority.value})')
print(f'  Status: {task.status.name}')

class TaskFilter(_jl.Walker):
    target_priority: Priority = _jl.field(factory=lambda: Priority.HIGH)
    matched: list = _jl.field(factory=lambda: [])

    @_jl.entry
    def traverse(self, here: _jl.Root) -> None:
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def filter(self, here: Task) -> None:
        print(f'    Checking task: {here.title}, priority={here.priority.name}')
        if here.priority == self.target_priority:
            self.matched.append(here.title)
            print('      Matched!')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.exit
    def report(self, here) -> None:
        print(f'  Found {len(self.matched)} tasks: {self.matched}')
print('\n=== 9. Enum in Walker Logic (OSP) ===')
task1 = Task(title='Critical Bug', priority=Priority.HIGH)
task2 = Task(title='Documentation', priority=Priority.LOW)
task3 = Task(title='Security Patch', priority=Priority.HIGH)
_jl.connect(left=_jl.root(), right=task1)
_jl.connect(left=_jl.root(), right=task2)
_jl.connect(left=_jl.root(), right=task3)
_jl.spawn(_jl.root(), TaskFilter(target_priority=Priority.HIGH))
print('\n✓ Enumerations demonstrated!')
