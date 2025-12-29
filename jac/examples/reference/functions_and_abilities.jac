# Functions and Abilities - Comprehensive function and ability syntax

# ===== Part 1: Basic Functions =====
obj BasicMath {
    # Function with typed parameters and return type
    def add(x: int, y: int) -> int {
        return x + y;
    }

    # Function with only return type (no params)
    def get_default -> int {
        return 42;
    }

    # Function with minimal type annotations (object type)
    def multiply(a: object, b: object) -> object {
        return a * b;
    }
}

# ===== Part 2: Static and Access Modifiers =====
obj Calculator {
    has instance_name: str = "calc";

    # Static function (belongs to class, not instance)
    static def square(x: int) -> int {
        return x * x;
    }

    # Static with private access
    static def : priv internal_helper(x: int) -> int {
        return x + 100;
    }

    # Public instance method
    def : pub public_method(x: int) -> int {
        return x * 2;
    }

    # Protected method
    def : protect protected_method -> str {
        return "protected";
    }
}

# ===== Part 3: Abstract Methods and Forward Declarations =====
obj AbstractCalculator {
    # Abstract method - must be implemented by subclasses
    def compute(x: int, y: int) -> int abs;
    # Forward declaration with params
    def process(value: float) -> float;
    # Forward declaration with variadic args
    def aggregate( *numbers: tuple)  -> float;
    # Forward declaration with kwargs
    def configure( **options: dict)  -> dict;
}

obj ConcreteCalculator(AbstractCalculator) {
    # Implement abstract method
    def compute(x: int, y: int) -> int {
        return x - y;
    }
}

# ===== Part 4: Implementation Blocks =====
# Implement forward-declared methods using impl
impl AbstractCalculator.process(
    value: float
) -> float {
    return value * 1.5;
}

impl AbstractCalculator.aggregate( *numbers: tuple)  -> float {
    return sum(numbers) / len(numbers) if numbers else 0.0;
}

impl AbstractCalculator.configure( **options: dict)  -> dict {
    options["configured"] = True;
    return options;
}

# ===== Part 5: Variadic Parameters =====
obj Variadic {
    # Positional variadic (*args)
    def sum_all( *values: tuple)  -> int {
        return sum(values);
    }

    # Keyword variadic (**kwargs)
    def collect_options( **opts: dict)  -> dict {
        return opts;
    }

    # Mixed: regular, *args, **kwargs
    def combined(base: int, *extras: tuple, **options: dict) -> dict {
        return {"base": base, "extras": extras, "options": options};
    }
}

# ===== Part 6: Async Functions =====
async def fetch_remote(url: str) -> dict {
    # Async function returning dict
    return {"url": url, "status": "fetched"};
}

async def process_batch(items: list) -> list {
    # Async processing
    return [item * 2 for item in items];
}

# ===== Part 7: Decorators =====
def logger(func: object) {
    print(f"Decorator applied to {func.__name__}");
    return func;
}

def tracer(func: object) {
    print(f"Tracer applied");
    return func;
}

# Single decorator
@logger
def logged_func(x: int) -> int {
    return x + 1;
}

# Multiple decorators (applied bottom-up)
@logger
@tracer
def double_decorated(x: int) -> int {
    return x * 2;
}

# ===== Part 8: Walker Abilities - Basic Events =====
walker BasicWalker {
    has counter: int = 0;

    # Entry ability - triggers when walker is spawned
    can initialize with entry {
        self.counter = 0;
        print("BasicWalker: initialized");
    }

    # Exit ability - triggers when walker finishes
    can finalize with exit {
        print(f"BasicWalker: done, counter={self.counter}");
    }
}

# ===== Part 9: Walker Abilities with Typed Node Context =====
node Person {
    has name: str,
        age: int = 0;
}

node City {
    has name: str,
        population: int = 0;
}

walker TypedWalker {
    has people_visited: int = 0,
        cities_visited: int = 0;

    # Ability triggered when visiting root
    can start with `root entry {
        print("TypedWalker: Starting at root");
        visit [-->];
    }

    # Ability triggered when visiting Person nodes
    can handle_person with Person entry {
        self.people_visited += 1;
        print(f"  Visiting person: {here.name}, age {here.age}");
        visit [-->];
    }

    # Ability triggered when visiting City nodes
    can handle_city with City entry {
        self.cities_visited += 1;
        print(f"  Visiting city: {here.name}, pop {here.population}");
        visit [-->];
    }

    # Exit ability with context
    can make_report with exit {
        print(
            f"TypedWalker: Visited {self.people_visited} people, {self.cities_visited} cities"
        );
    }
}

# ===== Part 10: Multiple Abilities on Same Node Type =====
walker MultiAbilityWalker {
    has stage: str = "initial";

    can first_pass with Person entry {
        if self.stage == "initial" {
            print(f"  First pass: {here.name}");
            self.stage = "processed";
        }
    }

    can second_pass with Person entry {
        if self.stage == "processed" {
            print(f"  Second pass: {here.name}");
        }
    }

    can start with `root entry {
        visit [-->];
    }
}

# ===== Part 11: Node Abilities =====
node InteractivePerson {
    has name: str,
        greeted: bool = False;

    # Node ability triggered when TypedWalker visits
    can greet_typed with TypedWalker entry {
        print(f"    {self.name} says: Hello TypedWalker!");
        self.greeted = True;
    }

    # Node ability triggered when MultiAbilityWalker visits
    can greet_multi with MultiAbilityWalker entry {
        print(f"    {self.name} says: Hello MultiAbilityWalker!");
    }
}

# ===== Part 12: Async Abilities =====
async walker AsyncWalker {
    async can process with entry {
        print("AsyncWalker: async processing");
    }

    async can handle with Person entry {
        print(f"AsyncWalker: async handling {here.name}");
        visit [-->];
    }
}

# ===== Part 13: Abstract Abilities =====
walker AbstractWalker {
    # Abstract ability - subclasses must implement
    can must_override with entry abs;
}

walker ConcreteWalker(AbstractWalker) {
    # Implement abstract ability
    can must_override with entry {
        print("ConcreteWalker: implemented abstract ability");
    }
}

# ===== Part 14: Static Abilities =====
walker StaticAbilityWalker {
    has instance_data: int = 0;

    # Static ability (rare, but allowed)
    static can class_level with entry {
        print("Static ability executed");
    }

    can instance_level with entry {
        self.instance_data += 1;
        print(f"Instance ability: data={self.instance_data}");
    }
}

# ===== Part 15: Ability Execution and Control Flow =====
walker ControlFlowWalker {
    has max_depth: int = 2,
        current_depth: int = 0;

    can traverse with Person entry {
        print(f"  Depth {self.current_depth}: {here.name}");

        if self.current_depth >= self.max_depth {
            print("  Max depth reached - stopping");
            disengage;
        }

        self.current_depth += 1;
        visit [-->];
    }

    can start with `root entry {
        visit [-->];
    }
}

# ===== Execution and Tests =====
with entry {
    print("=== 1. Basic Functions ===");
}

glob math = BasicMath();

with entry {
    print(f"add(5, 3) = {math.add(5, 3)}");
    print(f"get_default() = {math.get_default()}");
    print(f"multiply(4, 7) = {math.multiply(4, 7)}");

    print("\n=== 2. Static and Access Modifiers ===");
    print(f"Calculator.square(5) = {Calculator.square(5)}");
}

glob calc = Calculator();

with entry {
    print(f"calc.public_method(10) = {calc.public_method(10)}");

    print("\n=== 3. Abstract Methods ===");
}

glob concrete = ConcreteCalculator();

with entry {
    print(f"compute(10, 3) = {concrete.compute(10, 3)}");
    print(f"process(2.5) = {concrete.process(2.5)}");
    print(f"aggregate(1,2,3,4,5) = {concrete.aggregate(1, 2, 3, 4, 5)}");
    print(f"configure(x=1,y=2) = {concrete.configure(x=1, y=2)}");

    print("\n=== 4. Variadic Parameters ===");
}

glob v = Variadic();

with entry {
    print(f"sum_all(1,2,3,4,5) = {v.sum_all(1, 2, 3, 4, 5)}");
    print(f"collect_options(a=1,b=2) = {v.collect_options(a=1, b=2)}");
    print(f"combined(10, 20, 30, x=1, y=2) = {v.combined(10, 20, 30, x=1, y=2)}");

    print("\n=== 5. Basic Walker Abilities ===");
    root spawn BasicWalker();

    print("\n=== 6. Walker Abilities with Typed Node Context ===");
}

# Build graph: root -> alice (Person) -> nyc (City)
#                 \\-> bob (Person)
glob alice = Person(name="Alice", age=30),
     bob = Person(name="Bob", age=25),
     nyc = City(name="NYC", population=8000000);

with entry {
    root ++> alice;
    root ++> bob;
    alice ++> nyc;

    root spawn TypedWalker();

    print("\n=== 7. Multiple Abilities on Same Node Type ===");
    root spawn MultiAbilityWalker();

    print("\n=== 8. Node Abilities ===");
}

# Create InteractivePerson nodes
glob charlie = InteractivePerson(name="Charlie"),
     diana = InteractivePerson(name="Diana");

with entry {
    root ++> charlie;
    charlie ++> diana;

    root spawn TypedWalker();
    print(f"Charlie greeted: {charlie.greeted}");

    print("\n=== 9. Ability Execution and Control Flow ===");
}

# Build chain for depth test
glob person1 = Person(name="P1", age=20),
     person2 = Person(name="P2", age=21),
     person3 = Person(name="P3", age=22),
     person4 = Person(name="P4", age=23);

with entry {
    root ++> person1;
    person1 ++> person2;
    person2 ++> person3;
    person3 ++> person4;

    root spawn ControlFlowWalker();

    print("\n=== 10. Concrete Walker from Abstract ===");
    root spawn ConcreteWalker();

    print("\n✓ Functions and abilities demonstrated!");
}
