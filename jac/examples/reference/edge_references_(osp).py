"""Edge references (OSP): Edge reference expressions for graph queries."""

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


class Friend(Edge):
    since: int = 2020


class Colleague(Edge):
    years: int = 0


class EdgeRefWalker(Walker):

    @on_entry
    def demonstrate(self, here: Root) -> None:
        print("=== 1. Basic Edge References ===\n")
        alice = Person(name="Alice")
        bob = Person(name="Bob")
        charlie = Person(name="Charlie")
        connect(left=root(), right=alice)
        connect(left=alice, right=bob, edge=Friend(since=2015))
        connect(left=alice, right=charlie, edge=Colleague(years=3))
        print("From root:")
        out_from_root = refs(OPath(here).edge_out())
        print(f"  [-->] found {len(out_from_root)} outgoing nodes")
        for n in out_from_root:
            print(f"    - {n.name}")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def show_refs(self, here: Person) -> None:
        if here.name == "Alice":
            print(f"\\n=== 2. Edge References from {here.name} ===\\n")
            outgoing = refs(OPath(here).edge_out())
            print(f"Outgoing [-->]: {len(outgoing)} nodes")
            for n in outgoing:
                print(f"  - {n.name}")
            incoming = refs(OPath(here).edge_in())
            print(f"\\nIncoming [<--]: {len(incoming)} nodes")
            both = refs(OPath(here).edge_any())
            print(f"\\nBidirectional [<-->]: {len(both)} nodes")
            print("\n=== 3. Typed Edge References ===\n")
            friends = refs(OPath(here).edge_out(edge=lambda i: isinstance(i, Friend)))
            print(f"Friend edges [->:Friend:->]: {len(friends)} nodes")
            for n in friends:
                print(f"  - {n.name}")
            colleagues = refs(
                OPath(here).edge_out(edge=lambda i: isinstance(i, Colleague))
            )
            print(f"Colleague edges [->:Colleague:->]: {len(colleagues)} nodes")
            for n in colleagues:
                print(f"  - {n.name}")
            print("\n=== 4. Filtered Edge References ===\n")
            old_friends = refs(
                OPath(here).edge_out(
                    edge=lambda i: isinstance(i, Friend) and i.since < 2018
                )
            )
            print(f"Friends since before 2018: {len(old_friends)} nodes")
            experienced_colleagues = refs(
                OPath(here).edge_out(
                    edge=lambda i: isinstance(i, Colleague) and i.years > 2
                )
            )
            print(f"Colleagues with years > 2: {len(experienced_colleagues)} nodes")
            specific = refs(
                OPath(here).edge_out(
                    edge=lambda i: isinstance(i, Colleague)
                    and i.years >= 1
                    and (i.years <= 5)
                )
            )
            print(f"Colleagues with 1-5 years: {len(specific)} nodes")
            print("\n=== 5. Edge and Node Keywords ===\n")
            edge_objs = refs(OPath(here).edge_out().edge())
            print(f"[edge -->]: Retrieved {len(edge_objs)} edge objects")
            node_objs = refs(OPath(here).edge_out())
            print(f"[node -->]: Retrieved {len(node_objs)} node objects")
            print("\n=== 6. Chained Edge References ===\n")
            david = Person(name="David")
            bob_list = refs(OPath(here).edge_out(edge=lambda i: isinstance(i, Friend)))
            if bob_list:
                connect(left=bob_list[0], right=david, edge=Friend(since=2018))
            two_hop = refs(
                OPath(here)
                .edge_out(edge=lambda i: isinstance(i, Friend))
                .edge_out(edge=lambda i: isinstance(i, Friend))
            )
            print(
                f"[here ->:Friend:-> ->:Friend:->]: {len(two_hop)} nodes (2 hops via Friend)"
            )
            mixed = refs(
                OPath(here)
                .edge_out(edge=lambda i: isinstance(i, Friend))
                .edge_out(edge=lambda i: isinstance(i, Colleague))
            )
            print(
                f"[here ->:Friend:-> ->:Colleague:->]: {len(mixed)} nodes (Friend then Colleague)"
            )
            print("Can chain multiple: [node ->:T1:-> ->:T2:-> ->:T3:->]")
            print("\n=== 7. Edge References in Different Contexts ===\n")
            targets = refs(OPath(here).edge_out())
            print(f"Assignment: targets = [-->] → {len(targets)} nodes")
            if refs(OPath(here).edge_out()):
                print("Conditional: if [-->] → edges exist!")
            print("For loop:")
            for person in refs(OPath(here).edge_out()):
                print(f"  Iterating: {person.name}")
            print("\nVisit statement: visit [->:Friend:->]")
        disengage(self)
        return


class Summary(Walker):

    @on_entry
    def show(self, here: Root) -> None:
        print("\n" + "=" * 50)
        print("EDGE REFERENCE SYNTAX SUMMARY")
        print("=" * 50)
        print("\n** Basic Forms **")
        print("  [-->]           All outgoing edges")
        print("  [<--]           All incoming edges")
        print("  [<-->]          Bidirectional (both ways)")
        print("\n** Typed Forms **")
        print("  [->:Type:->]    Outgoing of specific type")
        print("  [<-:Type:<-]    Incoming of specific type")
        print("  [<-:Type:->]    Bidirectional of specific type")
        print("\n** Filtered Forms **")
        print("  [->:Type:attr > val:->]       Filter on edge attribute")
        print("  [->:Type:a > x, b < y:->]     Multiple conditions")
        print("\n** Special Forms **")
        print("  [edge -->]                    Get edge objects")
        print("  [node -->]                    Get node objects (explicit)")
        print("  [node ->:T1:-> ->:T2:->]      Chained (multi-hop)")
        print("\n** Common Usage **")
        print("  visit [-->];                  Visit all outgoing")
        print("  for n in [-->] { ... }        Iterate over nodes")
        print("  if [-->] { ... }              Check if edges exist")
        print("  targets = [->:Type:->];       Store in variable")
        print("\n" + "=" * 50)


print("=== Object Spatial References Demo ===\n")
spawn(root(), EdgeRefWalker())
spawn(root(), Summary())
print("\n✓ Edge reference variations demonstrated!")
