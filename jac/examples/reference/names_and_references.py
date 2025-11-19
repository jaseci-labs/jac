from __future__ import annotations
from jaclang.lib import (
    Node,
    Obj,
    OPath,
    Root,
    Walker,
    build_edge,
    connect,
    on_entry,
    refs,
    root,
    spawn,
    visit,
)


class Counter(Obj):
    count: int = 0

    def increment(self) -> None:
        self.count += 1
        print(self.count)


class Animal(Obj):

    def speak(self) -> None:
        print("animal sound")


class Dog(Animal, Obj):

    def speak(self) -> None:
        super().speak()
        print("woof")


class Task(Node):
    name: str


class TaskWalker(Walker):

    @on_entry
    def process(self, here: Task) -> None:
        print(f"at {here.name}")
        visit(self, refs(OPath(here).edge_out().visit()))


class Interactive(Node):
    visitor_name: str = "none"

    @on_entry
    def track(self, visitor: TaskWalker) -> None:
        self.visitor_name = visitor.__class__.__name__
        print(f"visited by {self.visitor_name}")


class RootWalker(Walker):

    @on_entry
    def start(self, here: Root) -> None:
        print(f"at root: {root()}")
        print(f"here is root: {here is root()}")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def at_task(self, here: Task) -> None:
        print(f"root is: {root()}")


class Configured(Obj):
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
task = Task(name="test")
inter = Interactive()
connect(left=root(), right=task)
connect(left=task, right=inter)
spawn(root(), TaskWalker())
spawn(root(), RootWalker())
cfg = Configured(value=10)
print(f"value={cfg.value}, doubled={cfg.doubled}")
