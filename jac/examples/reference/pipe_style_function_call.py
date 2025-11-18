"""Pipe-style function call: Pipe-style function invocation."""

from __future__ import annotations
from jaclang.lib import (
    Node,
    OPath,
    Root,
    Walker,
    build_edge,
    connect,
    disengage,
    field,
    on_entry,
    refs,
    root,
    spawn,
    visit,
)


class Task(Node):
    name: str
    priority: int = 0


class SimpleWalker(Walker):
    visited_names: list = field(factory=lambda: [])

    @on_entry
    def start(self, here: Root) -> None:
        print("SimpleWalker: Starting at root")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def process(self, here: Task) -> None:
        self.visited_names.append(here.name)
        print(f"  Processing: {here.name} (priority {here.priority})")
        visit(self, refs(OPath(here).edge_out().visit()))


class BasicSpawn(Walker):

    @on_entry
    def start(self, here: Root) -> None:
        print("BasicSpawn: started at root")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def handle_task(self, here: Task) -> None:
        print(f"  BasicSpawn at: {here.name}")
        visit(self, refs(OPath(here).edge_out().visit()))


class DepthFirst(Walker):
    depth: int = 0

    @on_entry
    def start(self, here: Root) -> None:
        print("DepthFirst: root")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def process(self, here: Task) -> None:
        self.depth += 1
        print(f"  Depth-first [{self.depth}]: {here.name}")
        visit(self, refs(OPath(here).edge_out().visit()))


class BreadthFirst(Walker):
    order: list = field(factory=lambda: [])

    @on_entry
    def start(self, here: Root) -> None:
        print("BreadthFirst: root")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def process(self, here: Task) -> None:
        self.order.append(here.name)
        print(f"  Breadth-first: {here.name}")
        visit(self, refs(OPath(here).edge_out().visit()))


class DataCollector(Walker):
    collected: list = field(factory=lambda: [])
    sum: int = 0

    @on_entry
    def start(self, here: Root) -> None:
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def collect(self, here: Task) -> None:
        self.collected.append(here.name)
        self.sum += here.priority
        visit(self, refs(OPath(here).edge_out().visit()))


class NodeSpawner(Walker):

    @on_entry
    def start(self, here: Root) -> None:
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def process(self, here: Task) -> None:
        print(f"  At {here.name}")
        if here.name == "Task2":
            print("    Spawning SubWalker from Task2")
            spawn(here, SubWalker())
        visit(self, refs(OPath(here).edge_out().visit()))


class SubWalker(Walker):

    @on_entry
    def start(self, here: Task) -> None:
        print(f"    SubWalker started at: {here.name}")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def handle(self, here: Task) -> None:
        print(f"      SubWalker processing: {here.name}")
        visit(self, refs(OPath(here).edge_out().visit()))


class ConstructedWalker(Walker):
    label: str
    max_visits: int = 5
    visits: int = 0

    @on_entry
    def start(self, here: Root) -> None:
        print(f"ConstructedWalker '{self.label}' starting")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def process(self, here: Task) -> None:
        self.visits += 1
        print(f"  [{self.label}] Visit {self.visits}: {here.name}")
        if self.visits >= self.max_visits:
            print(f"  [{self.label}] Max visits reached")
            disengage(self)
            return
        visit(self, refs(OPath(here).edge_out().visit()))


class Counter(Walker):
    total: int = 0

    @on_entry
    def start(self, here: Root) -> None:
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def count_task(self, here: Task) -> None:
        self.total += 1
        visit(self, refs(OPath(here).edge_out().visit()))


class Analyzer(Walker):
    high_priority: int = 0
    low_priority: int = 0

    @on_entry
    def start(self, here: Root) -> None:
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def analyze(self, here: Task) -> None:
        if here.priority > 5:
            self.high_priority += 1
        else:
            self.low_priority += 1
        visit(self, refs(OPath(here).edge_out().visit()))


class SyntaxDemo(Walker):

    @on_entry
    def start(self, here: Root) -> None:
        print("SyntaxDemo: Demonstrating all spawn syntaxes")


print("=== 1. Building Test Graph ===")
task1 = Task(name="Task1", priority=10)
task2 = Task(name="Task2", priority=5)
task3 = Task(name="Task3", priority=3)
task4 = Task(name="Task4", priority=8)
connect(left=root(), right=task1)
connect(left=task1, right=task2)
connect(left=task1, right=task3)
connect(left=task3, right=task4)
print("Graph: root -> Task1 -> Task2")
print("                 \\-> Task3 -> Task4\n")
print("=== 2. Basic spawn Keyword ===")
spawn(root(), BasicSpawn())
print("\n=== 3. Depth-First Spatial Call (:>) ===")
spawn(root(), DepthFirst())
print("\n=== 4. Breadth-First Spatial Call (|>) ===")
walker_bf = spawn(root(), BreadthFirst())
print(f"  Order visited: {walker_bf.order}")
print("\n=== 5. Walker Return Values ===")
collector = spawn(root(), DataCollector())
print(f"  Collected: {collector.collected}")
print(f"  Sum of priorities: {collector.sum}")
print("\n=== 6. Walker Spawned from Nodes ===")
spawn(root(), NodeSpawner())
print("\n=== 7. Walker Construction with Arguments ===")
w1 = spawn(root(), ConstructedWalker(label="Alpha", max_visits=2))
print(f"  Walker visited {w1.visits} tasks")
print("\n=== 8. Multiple Walkers on Same Graph ===")
counter = spawn(root(), Counter())
analyzer = spawn(root(), Analyzer())
print(f"  Counter: {counter.total} tasks")
print(
    f"  Analyzer: {analyzer.high_priority} high, {analyzer.low_priority} low priority"
)
print("\n=== 9. Spawn Syntax Variations ===")
spawn(root(), SyntaxDemo())
spawn(root(), SyntaxDemo())
spawn(root(), SyntaxDemo())
spawn(SyntaxDemo(), root())
demo = SyntaxDemo()
spawn(root(), demo)
print("\n=== 10. Traversal Strategy Comparison ===")
a = Task(name="A", priority=1)
b = Task(name="B", priority=2)
c = Task(name="C", priority=3)
d = Task(name="D", priority=4)
e = Task(name="E", priority=5)
connect(left=root(), right=a)
connect(left=a, right=b)
connect(left=a, right=c)
connect(left=b, right=d)
connect(left=b, right=e)
print("New graph: root -> A -> B -> D")
print("                    \\   \\-> E")
print("                     \\-> C\n")
print("  Depth-first (:>):")
df = spawn(root(), SimpleWalker())
print(f"    Visited: {df.visited_names}")
print("\n  Breadth-first (|>):")
bf = spawn(root(), SimpleWalker())
print(f"    Visited: {bf.visited_names}")
print("\n✓ Object spatial calls demonstrated!")
