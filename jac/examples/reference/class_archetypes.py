from __future__ import annotations
from jaclang.lib import (
    Edge,
    Node,
    Obj,
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


class ClassicAnimal:

    def __init__(
        self: ClassicAnimal, species: str, age: int, name: str = "Unnamed"
    ) -> None:
        self.species = species
        self.age = age
        self.name = name

    def describe(self: ClassicAnimal) -> None:
        print(f"{self.name} is a {self.age} year old {self.species}")


class Animal(Obj):
    species: str = "Unknown"
    age: int = 0

    def make_sound(self) -> None:
        print(f"{self.species} makes a sound")


class Domesticated(Obj):
    owner: str = "None"
    trained: bool = False

    def train(self) -> None:
        self.trained = True
        print(f"Training {self.owner}'s pet")


class Mammal(Obj):
    warm_blooded: bool = True


class Pet(Animal, Domesticated, Mammal, Node):
    name: str = "Unnamed"
    favorite_toy: str = "ball"

    def play(self) -> None:
        print(f"{self.name} plays with {self.favorite_toy}")

    @on_entry
    def greet_person(self, visitor: Person) -> None:
        print(f"  {self.name} wags tail at {visitor.name}")


class Relationship(Edge):
    strength: int = 5
    since: int = 2020

    def strengthen(self) -> None:
        self.strength += 1
        print(f"Relationship strengthened to {self.strength}")


class Ownership(Edge):
    duration_years: int = 0

    @on_entry
    def track(self, visitor: OwnershipWalker) -> None:
        print(f"  Edge: Ownership duration = {self.duration_years} years")
        self.duration_years += 1


class Person(Animal, Walker):
    name: str = "Person"
    visited_count: int = 0

    @on_entry
    def greet(self, here: Root) -> None:
        print(f"{self.name}: Starting walk from root")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def visit_pet(self, here: Pet) -> None:
        self.visited_count += 1
        print(f"{self.name} visits {here.name}")
        visit(self, refs(OPath(here).edge_out().visit()))


class Caretaker(Person, Walker):
    care_quality: int = 10

    @on_entry
    def care_for(self, here: Pet) -> None:
        print(f"{self.name} cares for {here.name} (quality: {self.care_quality})")
        visit(self, refs(OPath(here).edge_out().visit()))


class Veterinarian(Caretaker, Walker):
    specialty: str = "general"

    @on_entry
    def examine(self, here: Pet) -> None:
        print(f"Dr. {self.name} ({self.specialty}) examines {here.name}")
        visit(self, refs(OPath(here).edge_out().visit()))


class AsyncInspector(Walker):
    __jac_async__ = True
    inspected: list = field(factory=lambda: [])

    @on_entry
    async def inspect(self, here: Root) -> None:
        print("AsyncInspector: starting")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    async def check(self, here: Pet) -> None:
        self.inspected.append(here.name)
        print(f"  Async checking: {here.name}")
        visit(self, refs(OPath(here).edge_out().visit()))


class PrivateConfig(Obj):
    secret_key: str = "hidden"


class PublicAPI(Obj):
    version: str = "1.0"


class ProtectedResource(Obj):
    resource_id: int = 0


class AnimalNode(Node):
    animal_type: str = "wild"
    habitat: str = "forest"

    def describe(self) -> None:
        print(f"AnimalNode: {self.animal_type} in {self.habitat}")


class SpecializedWalker(Walker):
    specialization: str = "research"

    @on_entry
    def process(self, visitor: AnimalNode) -> None:
        print(f"SpecializedWalker ({self.specialization}): Processing node")
        disengage(visitor)
        return


class SpecialEdge(Edge):
    edge_weight: float = 1.0

    def get_weight(self) -> float:
        return self.edge_weight


def print_bases(cls: type) -> type:
    print(f"Archetype {cls.__name__} bases: {[c.__name__ for c in cls.__bases__]}")
    return cls


def track_creation(cls: type) -> type:
    print(f"Created archetype: {cls.__name__}")
    return cls


@print_bases
@track_creation
class DecoratedNode(Pet, Node):
    special_attr: str = "decorated"


class OwnershipWalker(Walker):

    @on_entry
    def start(self, here: Root) -> None:
        print("OwnershipWalker: tracking ownership edges")
        visit(self, refs(OPath(here).edge_out().visit()))

    @on_entry
    def visit_node(self, here: Pet) -> None:
        print(f"  At pet: {here.name}")
        visit(self, refs(OPath(here).edge_out().edge().visit()))


print("=== 1. Basic Archetypes ===")
print("\n--- Class with Init Constructor (Python-style explicit self) ---")
classic = ClassicAnimal("Cat", 3, "Whiskers")
classic.describe()
classic2 = ClassicAnimal("Bird", 1)
classic2.describe()
print("\n--- Object with Has Declarations (implicit self) ---")
animal1 = Animal()
animal2 = Animal()
print(
    f"Before assignment - animal1.species: {animal1.species}, animal2.species: {animal2.species}"
)
animal1.species = "Dog"
print(
    f"After animal1.species = 'Dog' - animal1.species: {animal1.species}, animal2.species: {animal2.species}"
)
print("Note: Each obj instance has its own copy of the variable")
animal1.make_sound()
dom = Domesticated()
dom.owner = "Alice"
dom.trained = True
print(f"Owner: {dom.owner}, Trained: {dom.trained}")
print("\n=== 2. Multiple Inheritance ===")
pet1 = Pet()
pet1.name = "Buddy"
pet1.species = "Dog"
pet1.owner = "Bob"
pet1.play()
pet1.train()
print(f"Warm blooded: {pet1.warm_blooded}")
print("\n=== 3. Edge Methods ===")
rel = Relationship()
rel.strength = 8
rel.strengthen()
print("\n=== 4. Walker Inheritance ===")
pet2 = Pet()
pet2.name = "Max"
pet2.species = "Cat"
connect(left=connect(left=root(), right=pet1), right=pet2)
person = Person()
person.name = "Alice"
person.species = "Human"
spawn(root(), person)
print(f"Alice visited {person.visited_count} pets")
vet = Veterinarian()
vet.name = "Dr.Smith"
vet.specialty = "canine"
vet.species = "Human"
spawn(root(), vet)
print("\n=== 5. Edge Abilities ===")
owner = Pet()
owner.name = "Owner"
owned = Pet()
owned.name = "Owned"
connect(
    left=connect(left=root(), right=owner),
    right=owned,
    edge=Ownership(duration_years=3),
)
spawn(root(), OwnershipWalker())
print("\n=== 6. Access Modifiers ===")
print(
    f"Private: {PrivateConfig().secret_key}, Public: {PublicAPI().version}, Protected: {ProtectedResource().resource_id}"
)
print("\n=== 7. Forward Declarations ===")
animal_node = AnimalNode()
animal_node.animal_type = "lion"
animal_node.describe()
print(f"Edge weight: {SpecialEdge().get_weight()}")
connect(left=root(), right=animal_node)
spec = SpecializedWalker()
spec.specialization = "wildlife"
spawn(animal_node, spec)
print("\n=== 8. Decorators ===")
decorated = DecoratedNode()
decorated.name = "Deco"
print(f"Decorated: {decorated.special_attr}")
print("\n✓ All features demonstrated!")
