# Archetypes - All 5 types: class, obj, node, edge, walker

# Class with init constructor (Python-style with explicit self)
# Note: No 'has' declarations - init creates instance variables directly
class ClassicAnimal {
    def init(self: ClassicAnimal, species: str, age: int, name: str = "Unnamed") {
        self.species = species;
        self.age = age;
        self.name = name;
    }

    def describe(self: ClassicAnimal) {
        print(f"{self.name} is a {self.age} year old {self.species}");
    }
}

# Object archetype with has declarations (implicit self in methods)
obj Animal {
    has species: str = "Unknown",
        age: int = 0;

    def make_sound {
        print(f"{self.species} makes a sound");
    }
}

# Object archetype (implicit self in methods)
obj Domesticated {
    has owner: str = "None",
        trained: bool = False;

    def train {  # No self parameter - it's implicit in obj
        self.trained = True;
        print(f"Training {self.owner}'s pet");
    }
}

obj Mammal {
    has warm_blooded: bool = True;
}

# Node with multiple inheritance
node Pet(Animal, Domesticated, Mammal) {
    has name: str = "Unnamed",
        favorite_toy: str = "ball";

    def play {
        print(f"{self.name} plays with {self.favorite_toy}");
    }

    can greet_person with Person entry {
        print(f"  {self.name} wags tail at {visitor.name}");
    }
}

# Edge with public access modifier and method
edge:pub Relationship {
    has strength: int = 5,
        since: int = 2020;

    def strengthen {
        self.strength += 1;
        print(f"Relationship strengthened to {self.strength}");
    }
}

# Edge with walker ability
edge Ownership {
    has duration_years: int = 0;

    can track with OwnershipWalker entry {
        print(f"  Edge: Ownership duration = {self.duration_years} years");
        self.duration_years += 1;
    }
}

# Walker with inheritance chain (Person -> Caretaker -> Veterinarian)
walker Person(Animal) {
    has name: str = "Person",
        visited_count: int = 0;

    can greet with `root entry {
        print(f"{self.name}: Starting walk from root");
        visit [-->];
    }

    can visit_pet with Pet entry {
        self.visited_count += 1;
        print(f"{self.name} visits {here.name}");
        visit [-->];
    }
}

walker Caretaker(Person) {
    has care_quality: int = 10;

    can care_for with Pet entry {
        print(f"{self.name} cares for {here.name} (quality: {self.care_quality})");
        visit [-->];
    }
}

walker Veterinarian(Caretaker) {
    has specialty: str = "general";

    can examine with Pet entry {
        print(f"Dr. {self.name} ({self.specialty}) examines {here.name}");
        visit [-->];
    }
}

# Async walker
async walker AsyncInspector {
    has inspected: list = [];

    async can inspect with `root entry {
        print("AsyncInspector: starting");
        visit [-->];
    }

    async can check with Pet entry {
        self.inspected.append(here.name);
        print(f"  Async checking: {here.name}");
        visit [-->];
    }
}

# Access modifiers: private, public, protected
obj:priv PrivateConfig {
    has secret_key: str = "hidden";
}

obj:pub PublicAPI {
    has version: str = "1.0";
}

obj:protect ProtectedResource {
    has resource_id: int = 0;
}

# Forward declarations
node AnimalNode;
walker SpecializedWalker;
edge SpecialEdge;

# Implementation blocks for forward declarations
impl AnimalNode{
    has animal_type: str = "wild",
        habitat: str = "forest";
    def describe {
        print(f"AnimalNode: {self.animal_type} in {self.habitat}");
    }
}

impl SpecializedWalker{
    has specialization: str = "research";
    can process with AnimalNode entry {
        print(f"SpecializedWalker ({self.specialization}): Processing node");
        disengage;
    }
}

impl SpecialEdge{
    has edge_weight: float = 1.0;
    def get_weight -> float {
        return self.edge_weight;
    }
}

# Decorators on archetypes
def print_bases(cls: type) -> type {
    print(f"Archetype {cls.__name__} bases: {[c.__name__ for c in cls.__bases__]}");
    return cls;
}

def track_creation(cls: type) -> type {
    print(f"Created archetype: {cls.__name__}");
    return cls;
}

@print_bases
@track_creation
node DecoratedNode(Pet) {
    has special_attr: str = "decorated";
}

# Walker for edge abilities
walker OwnershipWalker {
    can start with `root entry {
        print("OwnershipWalker: tracking ownership edges");
        visit [-->];
    }

    can visit_node with Pet entry {
        print(f"  At pet: {here.name}");
        visit [edge -->];
    }
}

# ===== Tests =====
with entry {
    print("=== 1. Basic Archetypes ===");

    print("\n--- Class with Init Constructor (Python-style explicit self) ---");
}

glob classic = ClassicAnimal("Cat", 3, "Whiskers");

with entry {
    classic.describe();
}

glob classic2 = ClassicAnimal("Bird", 1);

with entry {
    classic2.describe();

    print("\n--- Object with Has Declarations (implicit self) ---");
}

# Demonstrate that obj has variables are instance variables (not class variables)
glob animal1 = Animal(),
     animal2 = Animal();

with entry {
    print(
        f"Before assignment - animal1.species: {animal1.species}, animal2.species: {animal2.species}"
    );

    # Assigning to obj instance variable
    animal1.species = "Dog";
    print(
        f"After animal1.species = 'Dog' - animal1.species: {animal1.species}, animal2.species: {animal2.species}"
    );
    print("Note: Each obj instance has its own copy of the variable");
    animal1.make_sound();
}

glob dom = Domesticated();

with entry {
    dom.owner = "Alice";
    dom.trained = True;
    print(f"Owner: {dom.owner}, Trained: {dom.trained}");

    print("\n=== 2. Multiple Inheritance ===");
}

glob pet1 = Pet();

with entry {
    pet1.name = "Buddy";
    pet1.species = "Dog";
    pet1.owner = "Bob";
    pet1.play();
    pet1.train();
    print(f"Warm blooded: {pet1.warm_blooded}");

    print("\n=== 3. Edge Methods ===");
}

glob rel = Relationship();

with entry {
    rel.strength = 8;
    rel.strengthen();

    print("\n=== 4. Walker Inheritance ===");
}

glob pet2 = Pet();

with entry {
    pet2.name = "Max";
    pet2.species = "Cat";
    root ++> pet1 ++> pet2;
}

glob person = Person();

with entry {
    person.name = "Alice";
    person.species = "Human";
    root spawn person;
    print(f"Alice visited {person.visited_count} pets");
}

glob vet = Veterinarian();

with entry {
    vet.name = "Dr.Smith";
    vet.specialty = "canine";
    vet.species = "Human";
    root spawn vet;

    print("\n=== 5. Edge Abilities ===");
}

glob owner = Pet();

with entry {
    owner.name = "Owner";
}

glob owned = Pet();

with entry {
    owned.name = "Owned";
    root ++> owner +>: Ownership(duration_years=3) :+> owned;
    root spawn OwnershipWalker();

    print("\n=== 6. Access Modifiers ===");
    print(
        f"Private: {PrivateConfig().secret_key}, Public: {PublicAPI().version}, Protected: {ProtectedResource().resource_id}"
    );

    print("\n=== 7. Forward Declarations ===");
}

glob animal_node = AnimalNode();

with entry {
    animal_node.animal_type = "lion";
    animal_node.describe();
    print(f"Edge weight: {SpecialEdge().get_weight()}");

    root ++> animal_node;
}

glob spec = SpecializedWalker();

with entry {
    spec.specialization = "wildlife";
    animal_node spawn spec;

    print("\n=== 8. Decorators ===");
}

glob decorated = DecoratedNode();

with entry {
    decorated.name = "Deco";
    print(f"Decorated: {decorated.special_attr}");

    print("\n✓ All features demonstrated!");
}
