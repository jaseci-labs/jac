from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class Person(_jl.Node):
    name: str

class BasicDisengage(_jl.Walker):

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print('starting')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def visit_person(self, here: Person) -> None:
        print(f'at {here.name}')
        if here.name == 'Bob':
            print('found Bob, disengaging')
            _jl.disengage(self)
            return
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class ConditionalDisengage(_jl.Walker):
    max_visits: int = 2
    visit_count: int = 0

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def count_visits(self, here: Person) -> None:
        self.visit_count += 1
        print(f'visit {self.visit_count}: {here.name}')
        if self.visit_count >= self.max_visits:
            print('max visits reached, disengaging')
            _jl.disengage(self)
            return
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class SearchWalker(_jl.Walker):
    target_name: str
    found: bool = False

    @_jl.entry
    def search(self, here: _jl.Root) -> None:
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def check(self, here: Person) -> None:
        print(f'checking {here.name}')
        if here.name == self.target_name:
            print(f'found {here.name}!')
            self.found = True
            _jl.disengage(self)
            return
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))
alice = Person(name='Alice')
bob = Person(name='Bob')
charlie = Person(name='Charlie')
diana = Person(name='Diana')
_jl.connect(left=_jl.root(), right=alice)
_jl.connect(left=alice, right=bob)
_jl.connect(left=alice, right=charlie)
_jl.connect(left=bob, right=diana)
print('=== Basic Disengage ===')
_jl.spawn(_jl.root(), BasicDisengage())
print('\n=== Conditional Disengage ===')
_jl.spawn(_jl.root(), ConditionalDisengage())
print('\n=== Search Walker ===')
w = _jl.spawn(_jl.root(), SearchWalker(target_name='Charlie'))
print(f'found: {w.found}')
