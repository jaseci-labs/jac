from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class Counter(_jl.Obj):
    count: int = 0

    def increment(self) -> None:
        self.count += 1
        print(self.count)

class Animal(_jl.Obj):

    def speak(self) -> None:
        print('animal sound')

class Dog(Animal, _jl.Obj):

    def speak(self) -> None:
        super().speak()
        print('woof')

class Task(_jl.Node):
    name: str

class TaskWalker(_jl.Walker):

    @_jl.entry
    def process(self, here: Task) -> None:
        print(f'at {here.name}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class Interactive(_jl.Node):
    visitor_name: str = 'none'

    @_jl.entry
    def track(self, visitor: TaskWalker) -> None:
        self.visitor_name = visitor.__class__.__name__
        print(f'visited by {self.visitor_name}')

class RootWalker(_jl.Walker):

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print(f'at root: {_jl.root()}')
        print(f'here is root: {here is _jl.root()}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def at_task(self, here: Task) -> None:
        print(f'root is: {_jl.root()}')

class Configured(_jl.Obj):
    value: int
    doubled: int = 0

    def __init__(self, value: int) -> None:
        self.value = value
        self.__post_init__()

    def __post_init__(self) -> None:
        self.doubled = self.value * 2
c = Counter()
c.increment()
c.increment()
d = Dog()
d.speak()
task = Task(name='test')
inter = Interactive()
_jl.connect(left=_jl.root(), right=task)
_jl.connect(left=task, right=inter)
_jl.spawn(_jl.root(), TaskWalker())
_jl.spawn(_jl.root(), RootWalker())
cfg = Configured(value=10)
print(f'value={cfg.value}, doubled={cfg.doubled}')
