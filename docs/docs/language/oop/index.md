# Enhanced Object-Oriented Programming

Jac enhances traditional OOP with cleaner syntax, automatic constructors, enforced access control, and interface/implementation separation.

## Key Differences from Python

| Feature | Python | Jac |
|---------|--------|-----|
| Object definition | `class` | `obj` |
| Attributes | `self.attr` in `__init__` | `has attr: type` |
| Constructor | Manual `__init__` | Automatic from `has` |
| Access control | Convention (`_prefix`) | Enforced (`:pub`, `:priv`, `:protect`) |
| Interface separation | Not built-in | `.impl.jac` files |

---

## The `obj` Archetype

Jac uses `obj` to define objects with data (`has`) and methods (`def`).

### Basic Object Definition

```jac
obj Pet {
    has name: str;
    has species: str;
    has age: int;
    has is_adopted: bool = False;  # Default value

    def adopt() -> None {
        self.is_adopted = True;
        print(f"{self.name} has been adopted!");
    }

    def get_info() -> str {
        status = "adopted" if self.is_adopted else "available";
        return f"{self.name} is a {self.age}-year-old {self.species} ({status})";
    }
}

with entry {
    # Automatic constructor from 'has' attributes
    pet = Pet(name="Buddy", species="dog", age=3);
    print(pet.get_info());
    pet.adopt();
}
```

Output:

```
Buddy is a 3-year-old dog (available)
Buddy has been adopted!
```

### Automatic Constructors

Jac automatically generates constructors from `has` declarations - no `__init__` needed:

```jac
obj Point {
    has x: float;
    has y: float;
    has label: str = "unnamed";
}

with entry {
    # All these work
    p1 = Point(x=1.0, y=2.0);
    p2 = Point(x=0.0, y=0.0, label="origin");

    print(f"{p2.label}: ({p2.x}, {p2.y})");
}
```

### Post-Initialization with `postinit`

For computed attributes that depend on other attributes:

```jac
obj Rectangle {
    has width: float;
    has height: float;
    has area: float by postinit;

    def postinit() -> None {
        self.area = self.width * self.height;
    }
}

with entry {
    rect = Rectangle(width=5.0, height=3.0);
    print(f"Area: {rect.area}");  # Area: 15.0
}
```

---

## Inheritance

Create specialized objects from existing ones using parentheses:

```jac
obj Animal {
    has name: str;
    has species: str;
    has age: int;

    def make_sound() -> None {
        print(f"{self.name} makes a sound.");
    }
}

obj Dog(Animal) {
    has breed: str = "Unknown";

    def make_sound() -> None {
        print(f"{self.name} barks!");
    }

    def fetch() -> None {
        print(f"{self.name} fetches the ball!");
    }
}

obj Cat(Animal) {
    has indoor: bool = True;

    def make_sound() -> None {
        print(f"{self.name} meows!");
    }
}

with entry {
    dog = Dog(name="Rex", species="dog", age=3, breed="Labrador");
    cat = Cat(name="Whiskers", species="cat", age=2);

    dog.make_sound();  # Rex barks!
    dog.fetch();       # Rex fetches the ball!
    cat.make_sound();  # Whiskers meows!
}
```

---

## Access Control

Jac enforces access control with explicit modifiers.

### Modifiers

| Modifier | Scope | Use Case |
|----------|-------|----------|
| `:pub` | Anywhere (default) | Public API |
| `:priv` | Same object only | Internal state |
| `:protect` | Object and subclasses | Shared internals |

### Public (`:pub`)

Accessible from anywhere. This is the default, so `:pub` is optional:

```jac
obj PublicExample {
    has :pub name: str;           # Explicit public
    has value: int;               # Implicit public

    def :pub get_name() -> str {
        return self.name;
    }
}
```

### Private (`:priv`)

Only accessible within the object itself:

```jac
obj BankAccount {
    has :pub owner: str;
    has :priv balance: float = 0.0;
    has :priv pin: str;

    def :pub deposit(amount: float) -> None {
        self.balance += amount;
        print(f"Deposited ${amount}. New balance: ${self.balance}");
    }

    def :pub withdraw(amount: float, entered_pin: str) -> bool {
        if not self.verify_pin(entered_pin) {
            print("Invalid PIN");
            return False;
        }
        if amount > self.balance {
            print("Insufficient funds");
            return False;
        }
        self.balance -= amount;
        return True;
    }

    def :priv verify_pin(entered: str) -> bool {
        return entered == self.pin;
    }

    def :pub get_balance() -> float {
        return self.balance;
    }
}

with entry {
    acc = BankAccount(owner="Alice", pin="1234");
    acc.deposit(100.0);
    print(f"Balance: ${acc.get_balance()}");

    # acc.balance;     # Error - private
    # acc.verify_pin;  # Error - private
}
```

### Protected (`:protect`)

Accessible in the object and all subclasses:

```jac
obj Vehicle {
    has :pub make: str;
    has :pub model: str;
    has :protect mileage: int = 0;
    has :protect service_history: list[str] = [];

    def :protect add_service(service: str) -> None {
        self.service_history.append(service);
    }
}

obj Car(Vehicle) {
    has :pub num_doors: int = 4;

    def :pub drive(miles: int) -> None {
        self.mileage += miles;  # Can access protected
        print(f"Drove {miles} miles. Total: {self.mileage}");
    }

    def :pub service() -> None {
        self.add_service("Oil change");  # Can call protected
        print("Car serviced!");
    }
}

with entry {
    car = Car(make="Toyota", model="Camry");
    car.drive(100);
    car.service();
}
```

---

## Implementation Files

Separate interface from implementation using `.impl.jac` files.

### Interface File (`calculator.jac`)

```jac
obj Calculator {
    has precision: int = 2;

    def add(a: float, b: float) -> float;      # Signature only
    def subtract(a: float, b: float) -> float;
    def multiply(a: float, b: float) -> float;
    def divide(a: float, b: float) -> float;
}
```

### Implementation File (`calculator.impl.jac`)

```jac
impl Calculator.add {
    return round(a + b, self.precision);
}

impl Calculator.subtract {
    return round(a - b, self.precision);
}

impl Calculator.multiply {
    return round(a * b, self.precision);
}

impl Calculator.divide {
    if b == 0.0 {
        raise ValueError("Division by zero");
    }
    return round(a / b, self.precision);
}
```

### Usage

```jac
import from calculator { Calculator };

with entry {
    calc = Calculator(precision=3);
    print(calc.add(1.111, 2.222));      # 3.333
    print(calc.divide(10.0, 3.0));      # 3.333
}
```

### Benefits

- **Clean interfaces**: Users see what, not how
- **Maintainability**: Change implementation without touching interface
- **Testing**: Mock implementations for testing
- **Organization**: Keep complex logic separate

---

## Complete Example

```jac
"""Pet shop management system demonstrating OOP concepts."""

obj Pet {
    has :pub name: str;
    has :pub species: str;
    has :pub age: int;
    has :priv medical_records: list[str] = [];
    has :protect adoption_fee: float = 50.0;

    def :pub get_info() -> str {
        return f"{self.name} ({self.species}, {self.age} years)";
    }

    def :priv add_record(record: str) -> None {
        self.medical_records.append(record);
    }

    def :pub vaccinate(vaccine: str) -> None {
        self.add_record(f"Vaccinated: {vaccine}");
        print(f"{self.name} received {vaccine} vaccine");
    }
}

obj Dog(Pet) {
    has :pub breed: str = "Mixed";
    has :pub trained: bool = False;

    def :pub train() -> None {
        self.trained = True;
        self.adoption_fee *= 1.5;  # Access protected
        print(f"{self.name} is now trained! Fee: ${self.adoption_fee}");
    }
}

with entry {
    buddy = Dog(name="Buddy", species="dog", age=2, breed="Golden Retriever");
    buddy.train();
    buddy.vaccinate("Rabies");
    print(buddy.get_info());
}
```

---

## Summary

| Concept | Syntax | Purpose |
|---------|--------|---------|
| Object | `obj Name { }` | Define data + behavior |
| Attribute | `has name: type` | Declare data field |
| Default | `has name: type = value` | Default value |
| Post-init | `has name: type by postinit` | Computed attribute |
| Method | `def name() -> type { }` | Define behavior |
| Inheritance | `obj Child(Parent) { }` | Extend object |
| Public | `:pub` | Accessible anywhere |
| Private | `:priv` | Object-only access |
| Protected | `:protect` | Object + subclass access |
| Interface | `def name() -> type;` | Signature only |
| Implementation | `impl Obj.method { }` | Method body |

---

## Learn More

| Topic | Resource |
|-------|----------|
| OOP Fundamentals | [Chapter 7: Enhanced OOP](../../jac_book/chapter_7.md) |
| Implementation Separation | [Chapter 6: Code Organization](../../jac_book/chapter_6.md) |
| Spatial Objects | [Nodes & Edges (OSP)](../osp/index.md) |
| Type System | [Chapter 2: Variables & Types](../../jac_book/chapter_2.md) |
