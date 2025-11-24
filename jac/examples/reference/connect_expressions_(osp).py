"""Connect expressions (OSP): Graph edge creation and connection operators."""

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
    on_entry,
    refs,
    root,
    spawn,
    visit,
)


class Person(Node):
    name: str
    age: int = 0


class City(Node):
    name: str


class LivesIn(Edge):
    years: int = 0


class Friend(Edge):
    since: int = 2020


class Colleague(Edge):
    department: str


class GraphBuilder(Walker):

    @on_entry
    def build(self, here: Root) -> None:
        print("=== 1. Untyped Connect Operators ===")
        alice = Person(name="Alice", age=30)
        bob = Person(name="Bob", age=25)
        charlie = Person(name="Charlie", age=28)
        connect(left=alice, right=bob)
        print(f"Forward: {alice.name} ++> {bob.name}")
        connect(left=charlie, right=bob)
        print(f"Backward: {bob.name} <++ {charlie.name} (edge from Charlie to Bob)")
        connect(left=alice, right=charlie, undir=True)
        print(f"Bidirectional: {alice.name} <++> {charlie.name} (both directions)")
        print("\n=== 2. Typed Connect Operators ===")
        diana = Person(name="Diana", age=32)
        eve = Person(name="Eve", age=27)
        frank = Person(name="Frank", age=29)
        nyc = City(name="New York")
        london = City(name="London")
        connect(left=diana, right=nyc, edge=LivesIn)
        print(f"Typed forward: {diana.name} +>:LivesIn:+> {nyc.name}")
        connect(left=london, right=eve, edge=LivesIn)
        print(
            f"Typed backward: {eve.name} <+:LivesIn:<+ {london.name} (edge from London to Eve)"
        )
        connect(left=diana, right=eve, edge=Friend, undir=True)
        print(f"Typed bidirectional: {diana.name} <+:Friend:+> {eve.name}")
        print("\n=== 3. Edge Attribute Initialization ===")
        grace = Person(name="Grace", age=26)
        henry = Person(name="Henry", age=31)
        iris = Person(name="Iris", age=24)
        connect(left=grace, right=henry, edge=Friend(since=2015))
        print(
            f"Forward with attrs: {grace.name} +>: Friend(since=2015) :+> {henry.name}"
        )
        connect(left=iris, right=henry, edge=Friend(since=2018))
        print(
            f"Backward with attrs: {henry.name} <+: Friend(since=2018) :<+ {iris.name}"
        )
        connect(
            left=grace, right=iris, edge=Colleague(department="Engineering"), undir=True
        )
        print(
            f"Bidirectional with attrs: {grace.name} <+: Colleague(department='Engineering') :+> {iris.name}"
        )
        print("\n=== 4. Chained Connections ===")
        jack = Person(name="Jack", age=35)
        kate = Person(name="Kate", age=29)
        liam = Person(name="Liam", age=30)
        mike = Person(name="Mike", age=33)
        connect(
            left=connect(left=connect(left=jack, right=kate), right=liam), right=mike
        )
        print(f"Chain: {jack.name} ++> {kate.name} ++> {liam.name} ++> {mike.name}")
        print("\n=== 5. Inline Node Creation ===")
        nina = Person(name="Nina", age=28)
        connect(left=nina, right=Person(name="InlineNode1", age=35))
        connect(left=nina, right=Person(name="InlineNode2", age=40), edge=Friend)
        connect(
            left=nina, right=Person(name="InlineNode3", age=45), edge=Friend(since=2010)
        )
        print("Connected to 3 inline-created nodes (untyped, typed, with attrs)")
        print("\n=== 6. Connect to Multiple Targets ===")
        oscar = Person(name="Oscar", age=27)
        paula = Person(name="Paula", age=26)
        quinn = Person(name="Quinn", age=24)
        connect(left=oscar, right=paula)
        connect(left=oscar, right=quinn)
        connect(left=oscar, right=Person(name="Rita", age=30), edge=Friend)
        print(f"Connected {oscar.name} to 3 different targets")
        print("\n=== 7. Disconnect Operator ===")
        print(
            "Disconnect syntax: node del [-->] target (deletes edges from node to target)"
        )
        print("\n=== 8. Connect in Expressions ===")
        steve = Person(name="Steve", age=45)
        tina = Person(name="Tina", age=42)
        connect(left=steve, right=tina)
        print(f"Connect used in expression: {steve.name} ++> {tina.name}")
        print("\n✓ All connect expression features demonstrated!")
        disengage(self)
        return


class EdgeTraverser(Walker):

    @on_entry
    def traverse_root(self, here: Root) -> None:
        print("\n=== Edge Traversal with Visit ===")
        a = Person(name="A", age=25)
        b = Person(name="B", age=30)
        c = Person(name="C", age=35)
        connect(left=root(), right=a)
        connect(left=a, right=b, edge=Friend(since=2010))
        connect(left=a, right=c, edge=Colleague(department="Sales"))
        connect(left=b, right=c, edge=Friend(since=2015))
        print("Graph: root->A, A-Friend->B, A-Colleague->C, B-Friend->C")
        print("Visiting all outgoing edges from root:")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def traverse_person(self, here: Person) -> None:
        print(f"  Visited: {here.name}, age={here.age}")


spawn(root(), GraphBuilder())
spawn(root(), EdgeTraverser())
