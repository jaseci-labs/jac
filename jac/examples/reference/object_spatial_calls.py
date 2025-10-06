from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class Task(_jl.Node):
    name: str
    priority: int = 0

class SimpleWalker(_jl.Walker):
    visited_names: list = _jl.field(factory=lambda: [])

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print('SimpleWalker: Starting at root')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def process(self, here: Task) -> None:
        self.visited_names.append(here.name)
        print(f'  Processing: {here.name} (priority {here.priority})')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class BasicSpawn(_jl.Walker):

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print('BasicSpawn: started at root')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def handle_task(self, here: Task) -> None:
        print(f'  BasicSpawn at: {here.name}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class DepthFirst(_jl.Walker):
    depth: int = 0

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print('DepthFirst: root')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def process(self, here: Task) -> None:
        self.depth += 1
        print(f'  Depth-first [{self.depth}]: {here.name}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class BreadthFirst(_jl.Walker):
    order: list = _jl.field(factory=lambda: [])

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print('BreadthFirst: root')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def process(self, here: Task) -> None:
        self.order.append(here.name)
        print(f'  Breadth-first: {here.name}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class DataCollector(_jl.Walker):
    collected: list = _jl.field(factory=lambda: [])
    sum: int = 0

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def collect(self, here: Task) -> None:
        self.collected.append(here.name)
        self.sum += here.priority
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class NodeSpawner(_jl.Walker):

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def process(self, here: Task) -> None:
        print(f'  At {here.name}')
        if here.name == 'Task2':
            print('    Spawning SubWalker from Task2')
            _jl.spawn(here, SubWalker())
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class SubWalker(_jl.Walker):

    @_jl.entry
    def start(self, here: Task) -> None:
        print(f'    SubWalker started at: {here.name}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def handle(self, here: Task) -> None:
        print(f'      SubWalker processing: {here.name}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class ConstructedWalker(_jl.Walker):
    label: str
    max_visits: int = 5
    visits: int = 0

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print(f"ConstructedWalker '{self.label}' starting")
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def process(self, here: Task) -> None:
        self.visits += 1
        print(f'  [{self.label}] Visit {self.visits}: {here.name}')
        if self.visits >= self.max_visits:
            print(f'  [{self.label}] Max visits reached')
            _jl.disengage(self)
            return
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class Counter(_jl.Walker):
    total: int = 0

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def count_task(self, here: Task) -> None:
        self.total += 1
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class Analyzer(_jl.Walker):
    high_priority: int = 0
    low_priority: int = 0

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def analyze(self, here: Task) -> None:
        if here.priority > 5:
            self.high_priority += 1
        else:
            self.low_priority += 1
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class SyntaxDemo(_jl.Walker):

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print('SyntaxDemo: Demonstrating all spawn syntaxes')
print('=== 1. Building Test Graph ===')
task1 = Task(name='Task1', priority=10)
task2 = Task(name='Task2', priority=5)
task3 = Task(name='Task3', priority=3)
task4 = Task(name='Task4', priority=8)
_jl.connect(left=_jl.root(), right=task1)
_jl.connect(left=task1, right=task2)
_jl.connect(left=task1, right=task3)
_jl.connect(left=task3, right=task4)
print('Graph: root -> Task1 -> Task2')
print('                 \\-> Task3 -> Task4\n')
print('=== 2. Basic spawn Keyword ===')
_jl.spawn(_jl.root(), BasicSpawn())
print('\n=== 3. Depth-First Spatial Call (:>) ===')
_jl.spawn(_jl.root(), DepthFirst())
print('\n=== 4. Breadth-First Spatial Call (|>) ===')
walker_bf = _jl.spawn(_jl.root(), BreadthFirst())
print(f'  Order visited: {walker_bf.order}')
print('\n=== 5. Walker Return Values ===')
collector = _jl.spawn(_jl.root(), DataCollector())
print(f'  Collected: {collector.collected}')
print(f'  Sum of priorities: {collector.sum}')
print('\n=== 6. Walker Spawned from Nodes ===')
_jl.spawn(_jl.root(), NodeSpawner())
print('\n=== 7. Walker Construction with Arguments ===')
w1 = _jl.spawn(_jl.root(), ConstructedWalker(label='Alpha', max_visits=2))
print(f'  Walker visited {w1.visits} tasks')
print('\n=== 8. Multiple Walkers on Same Graph ===')
counter = _jl.spawn(_jl.root(), Counter())
analyzer = _jl.spawn(_jl.root(), Analyzer())
print(f'  Counter: {counter.total} tasks')
print(f'  Analyzer: {analyzer.high_priority} high, {analyzer.low_priority} low priority')
print('\n=== 9. Spawn Syntax Variations ===')
_jl.spawn(_jl.root(), SyntaxDemo())
_jl.spawn(_jl.root(), SyntaxDemo())
_jl.spawn(_jl.root(), SyntaxDemo())
_jl.spawn(SyntaxDemo(), _jl.root())
demo = SyntaxDemo()
_jl.spawn(_jl.root(), demo)
print('\n=== 10. Traversal Strategy Comparison ===')
a = Task(name='A', priority=1)
b = Task(name='B', priority=2)
c = Task(name='C', priority=3)
d = Task(name='D', priority=4)
e = Task(name='E', priority=5)
_jl.connect(left=_jl.root(), right=a)
_jl.connect(left=a, right=b)
_jl.connect(left=a, right=c)
_jl.connect(left=b, right=d)
_jl.connect(left=b, right=e)
print('New graph: root -> A -> B -> D')
print('                    \\   \\-> E')
print('                     \\-> C\n')
print('  Depth-first (:>):')
df = _jl.spawn(_jl.root(), SimpleWalker())
print(f'    Visited: {df.visited_names}')
print('\n  Breadth-first (|>):')
bf = _jl.spawn(_jl.root(), SimpleWalker())
print(f'    Visited: {bf.visited_names}')
print('\n✓ Object spatial calls demonstrated!')
