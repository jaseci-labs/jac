"""Walker visit and disengage (OSP): Graph traversal control with visit and disengage statements."""

from __future__ import annotations
from jaclang.lib import (
    Edge,
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


class Person(Node):
    name: str


class Friend(Edge):
    pass


class Colleague(Edge):
    strength: int


class BasicVisitor(Walker):

    @on_entry
    def start(self, here: Root) -> None:
        print("BasicVisitor: visiting outgoing edges")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def visit_person(self, here: Person) -> None:
        print(f"BasicVisitor: at {here.name}")


class VisitWithElse(Walker):

    @on_entry
    def start(self, here: Root) -> None:
        print("VisitWithElse: visiting with else clause")
        if not visit(self, refs(OPath(here).edge_out().visit())):
            print("VisitWithElse: no outgoing edges from root")

    @on_entry
    def visit_person(self, here: Person) -> None:
        print(f"VisitWithElse: at {here.name}")
        if not visit(self, refs(OPath(here).edge_out().visit())):
            print(f"VisitWithElse: leaf node - {here.name}")


class DirectVisit(Walker):
    target: Person

    @on_entry
    def start(self, here: Root) -> None:
        print("DirectVisit: going directly to target")
        visit(self, self.target)

    @on_entry
    def at_target(self, here: Person) -> None:
        print(f"DirectVisit: arrived at {here.name}")


class TypedVisit(Walker):

    @on_entry
    def start(self, here: Person) -> None:
        print(f"TypedVisit: at {here.name}, visiting Friend edges only")
        visit(
            self,
            refs(OPath(here).edge_out(edge=lambda i: isinstance(i, Friend)).visit()),
        )

    @on_entry
    def visit_friend(self, here: Person) -> None:
        print(f"TypedVisit: visited friend {here.name}")


class FilteredVisit(Walker):

    @on_entry
    def start(self, here: Person) -> None:
        print(f"FilteredVisit: visiting strong colleagues from {here.name}")
        visit(
            self,
            refs(
                OPath(here)
                .edge_out(edge=lambda i: isinstance(i, Colleague) and i.strength > 5)
                .visit()
            ),
        )

    @on_entry
    def visit_colleague(self, here: Person) -> None:
        print(f"FilteredVisit: visited colleague {here.name}")


class BasicDisengage(Walker):

    @on_entry
    def start(self, here: Root) -> None:
        print("BasicDisengage: starting traversal")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def visit_person(self, here: Person) -> None:
        print(f"BasicDisengage: at {here.name}")
        if here.name == "Bob":
            print("BasicDisengage: found Bob, disengaging")
            disengage(self)
            return
        print(f"BasicDisengage: continuing from {here.name}")
        visit(self, refs(OPath(here).edge_out().visit()))


class ConditionalDisengage(Walker):
    max_visits: int = 2
    visit_count: int = 0

    @on_entry
    def start(self, here: Root) -> None:
        print("ConditionalDisengage: starting")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def count_visits(self, here: Person) -> None:
        self.visit_count += 1
        print(f"ConditionalDisengage: visit {self.visit_count} at {here.name}")
        if self.visit_count >= self.max_visits:
            print("ConditionalDisengage: max visits reached, disengaging")
            disengage(self)
            return
        visit(self, refs(OPath(here).edge_out().visit()))


class SearchWalker(Walker):
    target_name: str
    found: bool = False

    @on_entry
    def search(self, here: Root) -> None:
        print(f"SearchWalker: searching for {self.target_name}")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def check(self, here: Person) -> None:
        print(f"SearchWalker: checking {here.name}")
        if here.name == self.target_name:
            print(f"SearchWalker: found {here.name}!")
            self.found = True
            disengage(self)
            return
        visit(self, refs(OPath(here).edge_out().visit()))


class MultiVisit(Walker):
    visit_phase: int = 1

    @on_entry
    def start(self, here: Root) -> None:
        print("MultiVisit: phase 1 - visit all outgoing")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def phase_one(self, here: Person) -> None:
        if self.visit_phase == 1:
            print(f"MultiVisit: phase 1 at {here.name}")
            self.visit_phase = 2
            visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def phase_two(self, here: Person) -> None:
        if self.visit_phase == 2:
            print(f"MultiVisit: phase 2 at {here.name}")


class ImmediateStop(Walker):

    @on_entry
    def self_destruct(self, here: Root) -> None:
        print("ImmediateStop: before disengage")
        disengage(self)
        return
        print("ImmediateStop: after disengage (never printed)")


class ComplexTraversal(Walker):
    depth: int = 0
    max_depth: int = 2
    nodes_visited: list[str] = field(factory=lambda: [])

    @on_entry
    def start(self, here: Root) -> None:
        print("ComplexTraversal: starting from root")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def traverse(self, here: Person) -> None:
        self.depth += 1
        self.nodes_visited.append(here.name)
        print(f"ComplexTraversal: depth {self.depth} at {here.name}")
        if self.depth >= self.max_depth:
            print("ComplexTraversal: max depth reached, disengaging")
            disengage(self)
            return
        if not visit(self, refs(OPath(here).edge_out().visit())):
            print(f"ComplexTraversal: leaf node at {here.name}")


alice = Person(name="Alice")
bob = Person(name="Bob")
charlie = Person(name="Charlie")
diana = Person(name="Diana")
eve = Person(name="Eve")
connect(left=root(), right=alice)
connect(left=alice, right=bob)
connect(left=alice, right=charlie)
connect(left=bob, right=diana)
connect(left=charlie, right=eve)
connect(left=alice, right=bob, edge=Friend)
connect(left=alice, right=charlie, edge=Colleague(strength=7))
connect(left=alice, right=diana, edge=Colleague(strength=3))
print("=== Basic Visit ===")
spawn(root(), BasicVisitor())
print("\n=== Visit with Else ===")
spawn(root(), VisitWithElse())
print("\n=== Direct Visit ===")
spawn(root(), DirectVisit(target=charlie))
print("\n=== Typed Visit ===")
spawn(alice, TypedVisit())
print("\n=== Filtered Visit ===")
spawn(alice, FilteredVisit())
print("\n=== Basic Disengage ===")
spawn(root(), BasicDisengage())
print("\n=== Conditional Disengage ===")
spawn(root(), ConditionalDisengage())
print("\n=== Search Walker ===")
w = spawn(root(), SearchWalker(target_name="Charlie"))
print(f"Found: {w.found}")
print("\n=== Multi Visit ===")
spawn(root(), MultiVisit())
print("\n=== Immediate Stop ===")
spawn(root(), ImmediateStop())
print("\n=== Complex Traversal ===")
ct = spawn(root(), ComplexTraversal())
print(f"Nodes visited: {ct.nodes_visited}")
