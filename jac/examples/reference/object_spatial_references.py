from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class Person(_jl.Node):
    name: str

class Friend(_jl.Edge):
    since: int = 2020

class Colleague(_jl.Edge):
    years: int = 0

class EdgeRefWalker(_jl.Walker):

    @_jl.entry
    def demonstrate(self, here: _jl.Root) -> None:
        print('=== 1. Basic Edge References ===\n')
        alice = Person(name='Alice')
        bob = Person(name='Bob')
        charlie = Person(name='Charlie')
        _jl.connect(left=_jl.root(), right=alice)
        _jl.connect(left=alice, right=bob, edge=Friend(since=2015))
        _jl.connect(left=alice, right=charlie, edge=Colleague(years=3))
        print('From root:')
        out_from_root = _jl.refs(_jl.Path(here)._out())
        print(f'  [-->] found {len(out_from_root)} outgoing nodes')
        for n in out_from_root:
            print(f'    - {n.name}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def show_refs(self, here: Person) -> None:
        if here.name == 'Alice':
            print(f'\\n=== 2. Edge References from {here.name} ===\\n')
            outgoing = _jl.refs(_jl.Path(here)._out())
            print(f'Outgoing [-->]: {len(outgoing)} nodes')
            for n in outgoing:
                print(f'  - {n.name}')
            incoming = _jl.refs(_jl.Path(here)._in())
            print(f'\\nIncoming [<--]: {len(incoming)} nodes')
            both = _jl.refs(_jl.Path(here)._any())
            print(f'\\nBidirectional [<-->]: {len(both)} nodes')
            print('\n=== 3. Typed Edge References ===\n')
            friends = _jl.refs(_jl.Path(here)._out(edge=lambda i: isinstance(i, Friend)))
            print(f'Friend edges [->:Friend:->]: {len(friends)} nodes')
            for n in friends:
                print(f'  - {n.name}')
            colleagues = _jl.refs(_jl.Path(here)._out(edge=lambda i: isinstance(i, Colleague)))
            print(f'Colleague edges [->:Colleague:->]: {len(colleagues)} nodes')
            for n in colleagues:
                print(f'  - {n.name}')
            print('\n=== 4. Filtered Edge References ===\n')
            old_friends = _jl.refs(_jl.Path(here)._out(edge=lambda i: isinstance(i, Friend) and i.since < 2018))
            print(f'Friends since before 2018: {len(old_friends)} nodes')
            experienced_colleagues = _jl.refs(_jl.Path(here)._out(edge=lambda i: isinstance(i, Colleague) and i.years > 2))
            print(f'Colleagues with years > 2: {len(experienced_colleagues)} nodes')
            specific = _jl.refs(_jl.Path(here)._out(edge=lambda i: isinstance(i, Colleague) and i.years >= 1 and (i.years <= 5)))
            print(f'Colleagues with 1-5 years: {len(specific)} nodes')
            print('\n=== 5. Edge and Node Keywords ===\n')
            edge_objs = _jl.refs(_jl.Path(here)._out().edge())
            print(f'[edge -->]: Retrieved {len(edge_objs)} edge objects')
            node_objs = _jl.refs(_jl.Path(here)._out())
            print(f'[node -->]: Retrieved {len(node_objs)} node objects')
            print('\n=== 6. Chained Edge References ===\n')
            david = Person(name='David')
            bob_list = _jl.refs(_jl.Path(here)._out(edge=lambda i: isinstance(i, Friend)))
            if bob_list:
                _jl.connect(left=bob_list[0], right=david, edge=Friend(since=2018))
            two_hop = _jl.refs(_jl.Path(here)._out(edge=lambda i: isinstance(i, Friend))._out(edge=lambda i: isinstance(i, Friend)))
            print(f'[here ->:Friend:-> ->:Friend:->]: {len(two_hop)} nodes (2 hops via Friend)')
            mixed = _jl.refs(_jl.Path(here)._out(edge=lambda i: isinstance(i, Friend))._out(edge=lambda i: isinstance(i, Colleague)))
            print(f'[here ->:Friend:-> ->:Colleague:->]: {len(mixed)} nodes (Friend then Colleague)')
            print('Can chain multiple: [node ->:T1:-> ->:T2:-> ->:T3:->]')
            print('\n=== 7. Edge References in Different Contexts ===\n')
            targets = _jl.refs(_jl.Path(here)._out())
            print(f'Assignment: targets = [-->] → {len(targets)} nodes')
            if _jl.refs(_jl.Path(here)._out()):
                print('Conditional: if [-->] → edges exist!')
            print('For loop:')
            for person in _jl.refs(_jl.Path(here)._out()):
                print(f'  Iterating: {person.name}')
            print('\nVisit statement: visit [->:Friend:->]')
        _jl.disengage(self)
        return

class Summary(_jl.Walker):

    @_jl.entry
    def show(self, here: _jl.Root) -> None:
        print('\n' + '=' * 50)
        print('EDGE REFERENCE SYNTAX SUMMARY')
        print('=' * 50)
        print('\n** Basic Forms **')
        print('  [-->]           All outgoing edges')
        print('  [<--]           All incoming edges')
        print('  [<-->]          Bidirectional (both ways)')
        print('\n** Typed Forms **')
        print('  [->:Type:->]    Outgoing of specific type')
        print('  [<-:Type:<-]    Incoming of specific type')
        print('  [<-:Type:->]    Bidirectional of specific type')
        print('\n** Filtered Forms **')
        print('  [->:Type:attr > val:->]       Filter on edge attribute')
        print('  [->:Type:a > x, b < y:->]     Multiple conditions')
        print('\n** Special Forms **')
        print('  [edge -->]                    Get edge objects')
        print('  [node -->]                    Get node objects (explicit)')
        print('  [node ->:T1:-> ->:T2:->]      Chained (multi-hop)')
        print('\n** Common Usage **')
        print('  visit [-->];                  Visit all outgoing')
        print('  for n in [-->] { ... }        Iterate over nodes')
        print('  if [-->] { ... }              Check if edges exist')
        print('  targets = [->:Type:->];       Store in variable')
        print('\n' + '=' * 50)
print('=== Object Spatial References Demo ===\n')
_jl.spawn(_jl.root(), EdgeRefWalker())
_jl.spawn(_jl.root(), Summary())
print('\n✓ Edge reference variations demonstrated!')
