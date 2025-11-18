"""Filter and assign comprehensions: Filter and assign comprehension syntax."""

from __future__ import annotations
from jaclang.lib import (
    Edge,
    Node,
    Obj,
    OPath,
    Root,
    Walker,
    assign_all,
    build_edge,
    connect,
    disengage,
    filter_on,
    on_entry,
    refs,
    root,
    spawn,
    visit,
)
import random


class TestObj(Obj):
    x: int = 0
    y: int = 0
    z: int = 0


class Person(Obj):
    name: str
    age: int = 0
    score: int = 0


class Employee(Node):
    name: str
    salary: int = 0
    department: str = "Unknown"


class ReportsTo(Edge):
    years: int = 0


class Collaborates(Edge):
    project: str = "None"


class ComprehensionDemo(Walker):

    @on_entry
    def demo_basic(self, here: Root) -> None:
        print("=== 1. Basic Filter Comprehension ===")
        random.seed(42)
        items = []
        i = 0
        while i < 10:
            items.append(TestObj(x=random.randint(0, 20), y=random.randint(0, 20), z=i))
            i += 1
        filtered = filter_on(items=items, func=lambda i: i.x >= 10 and i.y < 15)
        print(f"Filtered {len(items)} items to {len(filtered)} where x>=10 and y<15")
        print("\n=== 2. Filter with Single Condition ===")
        high_x = filter_on(items=items, func=lambda i: i.x > 15)
        print(f"Items with x > 15: {len(high_x)}")
        print("\n=== 3. Filter with Multiple Conditions ===")
        complex_filter = filter_on(
            items=items, func=lambda i: i.x >= 5 and i.x <= 15 and (i.y > 10)
        )
        print(f"Items with 5 <= x <= 15 and y > 10: {len(complex_filter)}")
        print("\n=== 4. Basic Assign Comprehension ===")
        objs = [TestObj(x=i) for i in range(3)]
        print(f"Before assign: x values = {[o.x for o in objs]}")
        assign_all(objs, (("y", "z"), (100, 200)))
        print(f"After assign(=y=100, z=200): y values = {[o.y for o in objs]}")
        print("\n=== 5. Chained Filter and Assign ===")
        people = [
            Person(name="Alice", age=25, score=80),
            Person(name="Bob", age=30, score=90),
            Person(name="Charlie", age=35, score=70),
        ]
        assign_all(
            filter_on(items=people, func=lambda i: i.age >= 30), (("score",), (95,))
        )
        print("People after filter(age>=30) + assign(score=95):")
        for p in people:
            print(f"  {p.name}: age={p.age}, score={p.score}")
        print("\n=== 6. Multiple Chained Filters ===")
        data = [TestObj(x=i, y=i * 2, z=i * 3) for i in range(10)]
        result = filter_on(
            items=filter_on(
                items=filter_on(items=data, func=lambda i: i.x > 2),
                func=lambda i: i.y < 15,
            ),
            func=lambda i: i.z >= 6,
        )
        print(f"Triple filtered from {len(data)} to {len(result)} items")
        print("\n=== Building Organization Graph ===")
        mgr = Employee(name="Manager", salary=100000, department="Engineering")
        dev1 = Employee(name="Dev1", salary=80000, department="Engineering")
        dev2 = Employee(name="Dev2", salary=75000, department="Engineering")
        dev3 = Employee(name="Dev3", salary=70000, department="Sales")
        connect(left=root(), right=mgr)
        connect(left=mgr, right=dev1, edge=ReportsTo(years=5))
        connect(left=mgr, right=dev2, edge=ReportsTo(years=2))
        connect(left=mgr, right=dev3, edge=ReportsTo(years=1))
        connect(
            left=dev1, right=dev2, edge=Collaborates(project="ProjectX"), undir=True
        )
        print("Graph built: Manager -> 3 Devs")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def demo_edge_filters(self, here: Employee) -> None:
        print(f"\\n=== At {here.name} ===")
        print("=== 7. Filter Comprehension on Edge Results ===")
        all_reports = refs(OPath(here).edge_out())
        high_paid = filter_on(items=all_reports, func=lambda i: i.salary > 75000)
        print(f"Direct reports: {len(all_reports)}, high paid (>75k): {len(high_paid)}")
        print("\n=== 8. Typed Edge with Node Filter ===")
        reports_via_edge = refs(
            OPath(here).edge_out(edge=lambda i: isinstance(i, ReportsTo))
        )
        engineering = filter_on(
            items=reports_via_edge, func=lambda i: i.department == "Engineering"
        )
        print(
            f"ReportsTo edges: {len(reports_via_edge)}, in Engineering: {len(engineering)}"
        )
        print("\n=== 9. Assign Comprehension on Edge Results ===")
        if len(all_reports) > 0:
            assign_all(all_reports, (("department",), ("Updated",)))
            print(f"Updated department for {len(all_reports)} employees")
        print("\n=== 10. Chained Edge Traversal + Filter + Assign ===")
        targets = refs(OPath(here).edge_out())
        if len(targets) > 0:
            high_earners = filter_on(items=targets, func=lambda i: i.salary >= 75000)
            if len(high_earners) > 0:
                assign_all(high_earners, (("salary",), (90000,)))
                print(f"Gave raise to {len(high_earners)} employees")
        print("\n=== 11. Outgoing Edge Results Only ===")
        out_edges = refs(OPath(here).edge_out())
        print(f"Total outgoing connections: {len(out_edges)}")
        disengage(self)
        return


print("=== 12. Filter Comprehension Comparison Operators ===")
nums = [TestObj(x=i) for i in range(10)]
equal_five = filter_on(items=nums, func=lambda i: i.x == 5)
not_five = filter_on(items=nums, func=lambda i: i.x != 5)
greater = filter_on(items=nums, func=lambda i: i.x > 5)
greater_eq = filter_on(items=nums, func=lambda i: i.x >= 5)
less = filter_on(items=nums, func=lambda i: i.x < 5)
less_eq = filter_on(items=nums, func=lambda i: i.x <= 5)
print(f"x==5: {len(equal_five)}, x!=5: {len(not_five)}")
print(f"x>5: {len(greater)}, x>=5: {len(greater_eq)}")
print(f"x<5: {len(less)}, x<=5: {len(less_eq)}")
print("\n=== 13. Assign with Multiple Attributes ===")
people = [Person(name=f"Person{i}") for i in range(5)]
assign_all(people, (("age", "score"), (25, 100)))
print(f"Assigned age=25, score=100 to {len(people)} people")
print(f"First person: age={people[0].age}, score={people[0].score}")
print("\n=== 14. Empty Collection Handling ===")
empty: list[object] = []
filtered_empty = filter_on(items=empty, func=lambda i: i.x > 5)
assigned_empty = assign_all(empty, (("x",), (10,)))
print(f"Filter on empty: {len(filtered_empty)}")
print(f"Assign on empty: {len(assigned_empty)}")
print("\n=== 15. Comprehension Return Values ===")
original = [TestObj(x=i) for i in range(3)]
filtered = filter_on(items=original, func=lambda i: i.x > 0)
assigned = assign_all(original, (("y",), (50,)))
print(f"Original list: {len(original)} items")
print(f"Filtered returns: {len(filtered)} items (new list)")
print(f"Assigned returns: {len(assigned)} items (same list, modified)")
print(f"Original[0].y after assign: {original[0].y}")
print("\n=== Running Walker Demo ===")
spawn(root(), ComprehensionDemo())
print("\n✓ All special comprehension variations demonstrated!")
