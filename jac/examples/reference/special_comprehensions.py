from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl
import random

class TestObj(_jl.Obj):
    x: int = 0
    y: int = 0
    z: int = 0

class Person(_jl.Obj):
    name: str
    age: int = 0
    score: int = 0

class Employee(_jl.Node):
    name: str
    salary: int = 0
    department: str = 'Unknown'

class ReportsTo(_jl.Edge):
    years: int = 0

class Collaborates(_jl.Edge):
    project: str = 'None'

class ComprehensionDemo(_jl.Walker):

    @_jl.entry
    def demo_basic(self, here: _jl.Root) -> None:
        print('=== 1. Basic Filter Comprehension ===')
        random.seed(42)
        items = []
        i = 0
        while i < 10:
            items.append(TestObj(x=random.randint(0, 20), y=random.randint(0, 20), z=i))
            i += 1
        filtered = _jl.filter(items=items, func=lambda i: i.x >= 10 and i.y < 15)
        print(f'Filtered {len(items)} items to {len(filtered)} where x>=10 and y<15')
        print('\n=== 2. Filter with Single Condition ===')
        high_x = _jl.filter(items=items, func=lambda i: i.x > 15)
        print(f'Items with x > 15: {len(high_x)}')
        print('\n=== 3. Filter with Multiple Conditions ===')
        complex_filter = _jl.filter(items=items, func=lambda i: i.x >= 5 and i.x <= 15 and (i.y > 10))
        print(f'Items with 5 <= x <= 15 and y > 10: {len(complex_filter)}')
        print('\n=== 4. Basic Assign Comprehension ===')
        objs = [TestObj(x=i) for i in range(3)]
        print(f'Before assign: x values = {[o.x for o in objs]}')
        _jl.assign(objs, (('y', 'z'), (100, 200)))
        print(f'After assign(=y=100, z=200): y values = {[o.y for o in objs]}')
        print('\n=== 5. Chained Filter and Assign ===')
        people = [Person(name='Alice', age=25, score=80), Person(name='Bob', age=30, score=90), Person(name='Charlie', age=35, score=70)]
        _jl.assign(_jl.filter(items=people, func=lambda i: i.age >= 30), (('score',), (95,)))
        print('People after filter(age>=30) + assign(score=95):')
        for p in people:
            print(f'  {p.name}: age={p.age}, score={p.score}')
        print('\n=== 6. Multiple Chained Filters ===')
        data = [TestObj(x=i, y=i * 2, z=i * 3) for i in range(10)]
        result = _jl.filter(items=_jl.filter(items=_jl.filter(items=data, func=lambda i: i.x > 2), func=lambda i: i.y < 15), func=lambda i: i.z >= 6)
        print(f'Triple filtered from {len(data)} to {len(result)} items')
        print('\n=== Building Organization Graph ===')
        mgr = Employee(name='Manager', salary=100000, department='Engineering')
        dev1 = Employee(name='Dev1', salary=80000, department='Engineering')
        dev2 = Employee(name='Dev2', salary=75000, department='Engineering')
        dev3 = Employee(name='Dev3', salary=70000, department='Sales')
        _jl.connect(left=_jl.root(), right=mgr)
        _jl.connect(left=mgr, right=dev1, edge=ReportsTo(years=5))
        _jl.connect(left=mgr, right=dev2, edge=ReportsTo(years=2))
        _jl.connect(left=mgr, right=dev3, edge=ReportsTo(years=1))
        _jl.connect(left=dev1, right=dev2, edge=Collaborates(project='ProjectX'), undir=True)
        print('Graph built: Manager -> 3 Devs')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def demo_edge_filters(self, here: Employee) -> None:
        print(f'\\n=== At {here.name} ===')
        print('=== 7. Filter Comprehension on Edge Results ===')
        all_reports = _jl.refs(_jl.Path(here)._out())
        high_paid = _jl.filter(items=all_reports, func=lambda i: i.salary > 75000)
        print(f'Direct reports: {len(all_reports)}, high paid (>75k): {len(high_paid)}')
        print('\n=== 8. Typed Edge with Node Filter ===')
        reports_via_edge = _jl.refs(_jl.Path(here)._out(edge=lambda i: isinstance(i, ReportsTo)))
        engineering = _jl.filter(items=reports_via_edge, func=lambda i: i.department == 'Engineering')
        print(f'ReportsTo edges: {len(reports_via_edge)}, in Engineering: {len(engineering)}')
        print('\n=== 9. Assign Comprehension on Edge Results ===')
        if len(all_reports) > 0:
            _jl.assign(all_reports, (('department',), ('Updated',)))
            print(f'Updated department for {len(all_reports)} employees')
        print('\n=== 10. Chained Edge Traversal + Filter + Assign ===')
        targets = _jl.refs(_jl.Path(here)._out())
        if len(targets) > 0:
            high_earners = _jl.filter(items=targets, func=lambda i: i.salary >= 75000)
            if len(high_earners) > 0:
                _jl.assign(high_earners, (('salary',), (90000,)))
                print(f'Gave raise to {len(high_earners)} employees')
        print('\n=== 11. Outgoing Edge Results Only ===')
        out_edges = _jl.refs(_jl.Path(here)._out())
        print(f'Total outgoing connections: {len(out_edges)}')
        _jl.disengage(self)
        return
print('=== 12. Filter Comprehension Comparison Operators ===')
nums = [TestObj(x=i) for i in range(10)]
equal_five = _jl.filter(items=nums, func=lambda i: i.x == 5)
not_five = _jl.filter(items=nums, func=lambda i: i.x != 5)
greater = _jl.filter(items=nums, func=lambda i: i.x > 5)
greater_eq = _jl.filter(items=nums, func=lambda i: i.x >= 5)
less = _jl.filter(items=nums, func=lambda i: i.x < 5)
less_eq = _jl.filter(items=nums, func=lambda i: i.x <= 5)
print(f'x==5: {len(equal_five)}, x!=5: {len(not_five)}')
print(f'x>5: {len(greater)}, x>=5: {len(greater_eq)}')
print(f'x<5: {len(less)}, x<=5: {len(less_eq)}')
print('\n=== 13. Assign with Multiple Attributes ===')
people = [Person(name=f'Person{i}') for i in range(5)]
_jl.assign(people, (('age', 'score'), (25, 100)))
print(f'Assigned age=25, score=100 to {len(people)} people')
print(f'First person: age={people[0].age}, score={people[0].score}')
print('\n=== 14. Empty Collection Handling ===')
empty = []
filtered_empty = _jl.filter(items=empty, func=lambda i: i.x > 5)
assigned_empty = _jl.assign(empty, (('x',), (10,)))
print(f'Filter on empty: {len(filtered_empty)}')
print(f'Assign on empty: {len(assigned_empty)}')
print('\n=== 15. Comprehension Return Values ===')
original = [TestObj(x=i) for i in range(3)]
filtered = _jl.filter(items=original, func=lambda i: i.x > 0)
assigned = _jl.assign(original, (('y',), (50,)))
print(f'Original list: {len(original)} items')
print(f'Filtered returns: {len(filtered)} items (new list)')
print(f'Assigned returns: {len(assigned)} items (same list, modified)')
print(f'Original[0].y after assign: {original[0].y}')
print('\n=== Running Walker Demo ===')
_jl.spawn(_jl.root(), ComprehensionDemo())
print('\n✓ All special comprehension variations demonstrated!')
