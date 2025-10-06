from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class Person(_jl.Node):
    name: str

class BasicVisitor(_jl.Walker):

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print('visiting outgoing')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def visit_person(self, here: Person) -> None:
        print(f'at {here.name}')

class VisitWithElse(_jl.Walker):

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print('visiting with else')
        if not _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit())):
            print('no outgoing edges')

    @_jl.entry
    def visit_person(self, here: Person) -> None:
        print(f'at {here.name}')
        if not _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit())):
            print('leaf node')

class DirectVisit(_jl.Walker):
    target: Person

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print('direct visit to target')
        _jl.visit(self, self.target)

    @_jl.entry
    def at_target(self, here: Person) -> None:
        print(f'arrived at {here.name}')
        _jl.disengage(self)
        return

class Friend(_jl.Edge):
    pass

class TypedVisit(_jl.Walker):

    @_jl.entry
    def start(self, here: Person) -> None:
        print(f'at {here.name}, visiting Friend edges')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out(edge=lambda i: isinstance(i, Friend)).visit()))

class Colleague(_jl.Edge):
    strength: int

class FilteredVisit(_jl.Walker):

    @_jl.entry
    def start(self, here: Person) -> None:
        print(f'visiting strong colleagues from {here.name}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out(edge=lambda i: isinstance(i, Colleague) and i.strength > 5).visit()))

class MultiVisit(_jl.Walker):

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print('first visit')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def continue_visit(self, here: Person) -> None:
        print(f'at {here.name}')
        print('second visit')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))
alice = Person(name='Alice')
bob = Person(name='Bob')
charlie = Person(name='Charlie')
_jl.connect(left=_jl.root(), right=alice)
_jl.connect(left=alice, right=bob)
_jl.connect(left=alice, right=charlie)
_jl.connect(left=alice, right=bob, edge=Friend)
_jl.connect(left=alice, right=charlie, edge=Colleague(strength=7))
print('=== Basic Visit ===')
_jl.spawn(_jl.root(), BasicVisitor())
print('\n=== Visit with Else ===')
_jl.spawn(_jl.root(), VisitWithElse())
print('\n=== Direct Visit ===')
_jl.spawn(_jl.root(), DirectVisit(target=charlie))
print('\n=== Typed Visit ===')
_jl.spawn(alice, TypedVisit())
print('\n=== Filtered Visit ===')
_jl.spawn(alice, FilteredVisit())
print('\n=== Multi Visit ===')
_jl.spawn(_jl.root(), MultiVisit())
