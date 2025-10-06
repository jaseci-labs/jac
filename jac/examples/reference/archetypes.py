from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class Animal:
    species: str = 'Unknown'
    age: int = 0

    def make_sound(self) -> None:
        print(f'{self.species} makes a sound')

class Domesticated(_jl.Obj):
    owner: str = 'None'
    trained: bool = False

    def train(self) -> None:
        self.trained = True
        print(f"Training {self.owner}'s pet")

class Mammal(_jl.Obj):
    warm_blooded: bool = True

class Pet(Animal, Domesticated, Mammal, _jl.Node):
    name: str = 'Unnamed'
    favorite_toy: str = 'ball'

    def play(self) -> None:
        print(f'{self.name} plays with {self.favorite_toy}')

    @_jl.entry
    def greet_person(self, visitor: Person) -> None:
        print(f'  {self.name} wags tail at {visitor.name}')

class Relationship(_jl.Edge):
    strength: int = 5
    since: int = 2020

    def strengthen(self) -> None:
        self.strength += 1
        print(f'Relationship strengthened to {self.strength}')

class Ownership(_jl.Edge):
    duration_years: int = 0

    @_jl.entry
    def track(self, visitor: OwnershipWalker) -> None:
        print(f'  Edge: Ownership duration = {self.duration_years} years')
        self.duration_years += 1

class Person(Animal, _jl.Walker):
    name: str = 'Person'
    visited_count: int = 0

    @_jl.entry
    def greet(self, here: _jl.Root) -> None:
        print(f'{self.name}: Starting walk from root')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def visit_pet(self, here: Pet) -> None:
        self.visited_count += 1
        print(f'{self.name} visits {here.name}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class Caretaker(Person, _jl.Walker):
    care_quality: int = 10

    @_jl.entry
    def care_for(self, here: Pet) -> None:
        print(f'{self.name} cares for {here.name} (quality: {self.care_quality})')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class Veterinarian(Caretaker, _jl.Walker):
    specialty: str = 'general'

    @_jl.entry
    def examine(self, here: Pet) -> None:
        print(f'Dr. {self.name} ({self.specialty}) examines {here.name}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class AsyncInspector(_jl.Walker):
    __jac_async__ = True
    inspected: list = _jl.field(factory=lambda: [])

    @_jl.entry
    async def inspect(self, here: _jl.Root) -> None:
        print('AsyncInspector: starting')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    async def check(self, here: Pet) -> None:
        self.inspected.append(here.name)
        print(f'  Async checking: {here.name}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class PrivateConfig(_jl.Obj):
    secret_key: str = 'hidden'

class PublicAPI(_jl.Obj):
    version: str = '1.0'

class ProtectedResource(_jl.Obj):
    resource_id: int = 0

class AnimalNode(_jl.Node):
    animal_type: str = 'wild'
    habitat: str = 'forest'

    def describe(self) -> None:
        print(f'AnimalNode: {self.animal_type} in {self.habitat}')

class SpecializedWalker(_jl.Walker):
    specialization: str = 'research'

    @_jl.entry
    def process(self, visitor: AnimalNode) -> None:
        print(f'SpecializedWalker ({self.specialization}): Processing node')
        _jl.disengage(visitor)
        return

class SpecialEdge(_jl.Edge):
    edge_weight: float = 1.0

    def get_weight(self) -> float:
        return self.edge_weight

def print_bases(cls: type) -> type:
    print(f'Archetype {cls.__name__} bases: {[c.__name__ for c in cls.__bases__]}')
    return cls

def track_creation(cls: type) -> type:
    print(f'Created archetype: {cls.__name__}')
    return cls

@print_bases
@track_creation
class DecoratedNode(Pet, _jl.Node):
    special_attr: str = 'decorated'

class OwnershipWalker(_jl.Walker):

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print('OwnershipWalker: tracking ownership edges')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def visit_node(self, here: Pet) -> None:
        print(f'  At pet: {here.name}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().edge().visit()))
print('=== 1. Basic Archetypes ===')
animal = Animal()
animal.species = 'Dog'
animal.make_sound()
dom = Domesticated()
dom.owner = 'Alice'
dom.trained = True
print(f'Owner: {dom.owner}, Trained: {dom.trained}')
print('\n=== 2. Multiple Inheritance ===')
pet1 = Pet()
pet1.name = 'Buddy'
pet1.species = 'Dog'
pet1.owner = 'Bob'
pet1.play()
pet1.train()
print(f'Warm blooded: {pet1.warm_blooded}')
print('\n=== 3. Edge Methods ===')
rel = Relationship()
rel.strength = 8
rel.strengthen()
print('\n=== 4. Walker Inheritance ===')
pet2 = Pet()
pet2.name = 'Max'
pet2.species = 'Cat'
_jl.connect(left=_jl.connect(left=_jl.root(), right=pet1), right=pet2)
person = Person()
person.name = 'Alice'
person.species = 'Human'
_jl.spawn(_jl.root(), person)
print(f'Alice visited {person.visited_count} pets')
vet = Veterinarian()
vet.name = 'Dr.Smith'
vet.specialty = 'canine'
vet.species = 'Human'
_jl.spawn(_jl.root(), vet)
print('\n=== 5. Edge Abilities ===')
owner = Pet()
owner.name = 'Owner'
owned = Pet()
owned.name = 'Owned'
_jl.connect(left=_jl.connect(left=_jl.root(), right=owner), right=owned, edge=Ownership(duration_years=3))
_jl.spawn(_jl.root(), OwnershipWalker())
print('\n=== 6. Access Modifiers ===')
print(f'Private: {PrivateConfig().secret_key}, Public: {PublicAPI().version}, Protected: {ProtectedResource().resource_id}')
print('\n=== 7. Forward Declarations ===')
animal_node = AnimalNode()
animal_node.animal_type = 'lion'
animal_node.describe()
print(f'Edge weight: {SpecialEdge().get_weight()}')
_jl.connect(left=_jl.root(), right=animal_node)
spec = SpecializedWalker()
spec.specialization = 'wildlife'
_jl.spawn(animal_node, spec)
print('\n=== 8. Decorators ===')
decorated = DecoratedNode()
decorated.name = 'Deco'
print(f'Decorated: {decorated.special_attr}')
print('\n✓ All features demonstrated!')
