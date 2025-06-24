# Chapter 7: Enhanced OOP - Objects and Classes

Jac takes the familiar concepts of object-oriented programming and enhances them with modern features like **automatic constructors**, **implementation separation**, and **improved access control**. This chapter shows how Jac builds on traditional OOP while making it more powerful and convenient.

!!! topic "Enhanced Object-Oriented Programming"
    Jac's enhanced OOP features eliminate boilerplate code while providing better type safety and code organization than traditional approaches.

## From Python `class` to Jac `obj`

!!! topic "The Evolution of Classes"
    While Python classes require manual constructor writing, Jac's `obj` archetype automatically generates constructors and handles common patterns for you.

### Traditional Python Classes

In Python, you must manually write constructors and handle instance variables:

```python
class Pet:
    def __init__(self, name: str, species: str, age: int):
        self.name = name
        self.species = species
        self.age = age
        self.is_adopted = False  # Default value

    def adopt(self):
        self.is_adopted = True
        print(f"{self.name} has been adopted!")

    def get_info(self):
        status = "adopted" if self.is_adopted else "available"
        return f"{self.name} is a {self.age}-year-old {self.species} ({status})"

# Usage
pet = Pet("Buddy", "dog", 3)
print(pet.get_info())
```

### Jac's Enhanced `obj`

!!! example "Simple Pet Class"
    === "Jac"
        <div class="code-block">
        ```jac
        obj Pet {
            has name: str;
            has species: str;
            has age: int;
            has is_adopted: bool = False;  # Automatic default

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
            # Automatic constructor from 'has' declarations
            pet = Pet(name="Buddy", species="dog", age=3);
            print(pet.get_info());
            pet.adopt();
        }
        ```
        </div>
    === "Python"
        ```python
        class Pet:
            def __init__(self, name: str, species: str, age: int, is_adopted: bool = False):
                self.name = name
                self.species = species
                self.age = age
                self.is_adopted = is_adopted

            def adopt(self):
                self.is_adopted = True
                print(f"{self.name} has been adopted!")

            def get_info(self):
                status = "adopted" if self.is_adopted else "available"
                return f"{self.name} is a {self.age}-year-old {self.species} ({status})"

        if __name__ == "__main__":
            pet = Pet(name="Buddy", species="dog", age=3)
            print(pet.get_info())
            pet.adopt()
        ```

## Automatic Constructors with `has`

!!! topic "Automatic Constructor Generation"
    The `has` keyword declares instance variables and automatically generates constructors, eliminating boilerplate code.

### Multiple Pets Example

!!! example "Pet Shop with Multiple Animals"
    === "Jac"
        <div class="code-block">
        ```jac
        obj Animal {
            has name: str;
            has age: int;
            has is_healthy: bool by postinit;

            def postinit() -> None {
                self.is_healthy = True;
            }

            def birthday() -> None {
                self.age += 1;
                print(f"Happy birthday {self.name}! Now {self.age} years old.");
            }
        }

        obj Dog(Animal) {
            has breed: str;
            has is_trained: bool = False;

            def bark() -> None {
                print(f"{self.name} the {self.breed} says: Woof!");
            }
        }

        obj Cat(Animal) {
            has indoor: bool = True;
            has favorite_toy: str = "ball of yarn";

            def meow() -> None {
                print(f"{self.name} says: Meow!");
            }
        }

        with entry {
            # Automatic constructors include parent class fields
            dog = Dog(name="Max", age=2, breed="Golden Retriever");
            cat = Cat(name="Whiskers", age=3, indoor=False, favorite_toy="feather");

            dog.bark();
            dog.birthday();

            cat.meow();
            print(f"{cat.name} is {'indoor' if cat.indoor else 'outdoor'}");
        }
        ```
        </div>
    === "Python"
        ```python
        class Animal:
            def __init__(self, name: str, age: int, is_healthy: bool = True):
                self.name = name
                self.age = age
                self.is_healthy = is_healthy

            def birthday(self):
                self.age += 1
                print(f"Happy birthday {self.name}! Now {self.age} years old.")

        class Dog(Animal):
            def __init__(self, name: str, age: int, breed: str, is_healthy: bool = True, is_trained: bool = False):
                super().__init__(name, age, is_healthy)
                self.breed = breed
                self.is_trained = is_trained

            def bark(self):
                print(f"{self.name} the {self.breed} says: Woof!")

        class Cat(Animal):
            def __init__(self, name: str, age: int, is_healthy: bool = True, indoor: bool = True, favorite_toy: str = "ball of yarn"):
                super().__init__(name, age, is_healthy)
                self.indoor = indoor
                self.favorite_toy = favorite_toy

            def meow(self):
                print(f"{self.name} says: Meow!")

        if __name__ == "__main__":
            dog = Dog(name="Max", age=2, breed="Golden Retriever")
            cat = Cat(name="Whiskers", age=3, indoor=False, favorite_toy="feather")

            dog.bark()
            dog.birthday()

            cat.meow()
            print(f"{cat.name} is {'indoor' if cat.indoor else 'outdoor'}")
        ```

### Advanced Constructor Features

!!! example "Constructor with Validation"
    === "Jac"
        <div class="code-block">
        ```jac
        obj Pet {
            has name: str;
            has species: str;
            has age: int;
            has is_adopted: bool = False;  # Automatic default

            def adopt() -> None {
                self.is_adopted = True;
                print(f"{self.name} has been adopted!");
            }

            def get_info() -> str {
                status = "adopted" if self.is_adopted else "available";
                return f"{self.name} is a {self.age}-year-old {self.species} ({status})";
            }
        }

        obj PetShop {
            has name: str;
            has pets: list[Pet] = [];
            has capacity: int = 10;
            has is_open: bool by postinit;  # Set in postinit

            def postinit() -> None {
                # Run after automatic initialization
                self.is_open = len(self.pets) < self.capacity;
                print(f"{self.name} shop initialized with {len(self.pets)} pets");
            }

            def add_pet(pet: Pet) -> bool {
                if len(self.pets) >= self.capacity {
                    print("Shop is at capacity!");
                    return False;
                }

                self.pets.append(pet);
                self.is_open = len(self.pets) < self.capacity;
                print(f"Added {pet.name} to {self.name}");
                return True;
            }

            def list_available_pets() -> None {
                available = [p for p in self.pets if not p.is_adopted];
                print(f"Available pets at {self.name}:");
                for pet in available {
                    print(f"  - {pet.get_info()}");
                }
            }
        }

        with entry {
            # Shop starts empty, postinit sets is_open
            shop = PetShop(name="Happy Paws Pet Shop");

            # Add some pets
            dog = Pet(name="Buddy", species="dog", age=3);
            cat = Pet(name="Mittens", species="cat", age=2);

            shop.add_pet(dog);
            shop.add_pet(cat);
            shop.list_available_pets();

            # Adopt a pet
            dog.adopt();
            shop.list_available_pets();
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List

        class PetShop:
            def __init__(self, name: str, capacity: int = 10):
                self.name = name
                self.pets: List[Pet] = []
                self.capacity = capacity
                self.is_open = len(self.pets) < self.capacity
                print(f"{self.name} shop initialized with {len(self.pets)} pets")

            def add_pet(self, pet):
                if len(self.pets) >= self.capacity:
                    print("Shop is at capacity!")
                    return False

                self.pets.append(pet)
                self.is_open = len(self.pets) < self.capacity
                print(f"Added {pet.name} to {self.name}")
                return True

            def list_available_pets(self):
                available = [p for p in self.pets if not p.is_adopted]
                print(f"\nAvailable pets at {self.name}:")
                for pet in available:
                    print(f"  - {pet.get_info()}")

        if __name__ == "__main__":
            shop = PetShop(name="Happy Paws Pet Shop")

            dog = Pet(name="Buddy", species="dog", age=3)
            cat = Pet(name="Mittens", species="cat", age=2)

            shop.add_pet(dog)
            shop.add_pet(cat)
            shop.list_available_pets()

            dog.adopt()
            shop.list_available_pets()
        ```

## Access Control with `:pub`, `:priv`, `:protect`

!!! topic "Explicit Access Control"
    Unlike Python's naming conventions, Jac provides explicit access control that's enforced at compile time.

### Python's Convention-Based Privacy

In Python, privacy is based on naming conventions that aren't enforced:

```python
class BankAccount:
    def __init__(self, account_number, balance):
        self.account_number = account_number  # Public
        self._balance = balance               # "Protected" (convention)
        self.__pin = "1234"                  # "Private" (name mangling)

    def get_balance(self):
        return self._balance  # Can still be accessed externally
```

### Jac's Enforced Access Control

!!! example "Access Control in Pet Management"
    === "Jac"
        <div class="code-block">
        ```jac
        obj PetRecord {
            # Public - anyone can access
            has :pub name: str;
            has :pub species: str;

            # Private - only this class
            has :priv owner_contact: str;
            has :priv microchip_id: str;

            # Protected - only this class and subclasses
            has :protect medical_history: list[str] = [];
            has :protect last_checkup: str = "";

            # Public method
            def :pub get_basic_info() -> str {
                return f"{self.name} is a {self.species}";
            }

            # Protected method - for vets and staff
            def :protect add_medical_record(record: str) -> None {
                self.medical_history.append(record);
                print(f"Medical record added for {self.name}");
            }

            # Private method - internal use only
            def :priv validate_contact(contact: str) -> bool {
                return "@" in contact and len(contact) > 5;
            }

            def :pub update_owner_contact(new_contact: str) -> bool {
                if self.validate_contact(new_contact) {
                    self.owner_contact = new_contact;
                    return True;
                }
                return False;
            }
        }

        obj VetRecord(PetRecord) {
            has :protect vet_notes: str = "";

            def :pub add_vet_note(note: str) -> None {
                # Can access protected members from parent
                self.add_medical_record(f"Vet note: {note}");
                self.vet_notes = note;
            }

            def :pub get_medical_summary() -> str {
                # Can access protected data
                record_count = len(self.medical_history);
                return f"{self.name} has {record_count} medical records";
            }
        }

        with entry {
            # Create a pet record
            pet = PetRecord(
                name="Fluffy",
                species="cat",
                owner_contact="owner@example.com",
                microchip_id="123456789"
            );

            # Public access works
            print(pet.get_basic_info());
            print(f"Pet name: {pet.name}");

            # Update contact through public method
            success = pet.update_owner_contact("new_owner@example.com");
            print(f"Contact updated: {success}");

            # Vet record with access to protected methods
            vet_record = VetRecord(
                name="Rex",
                species="dog",
                owner_contact="owner2@example.com",
                microchip_id="987654321"
            );

            vet_record.add_vet_note("Annual checkup - healthy");
            print(vet_record.get_medical_summary());
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List

        class PetRecord:
            def __init__(self, name: str, species: str, owner_contact: str, microchip_id: str):
                # Public
                self.name = name
                self.species = species

                # Protected (convention only)
                self._medical_history: List[str] = []
                self._last_checkup = ""

                # Private (name mangling, but still accessible)
                self.__owner_contact = owner_contact
                self.__microchip_id = microchip_id

            def get_basic_info(self) -> str:
                return f"{self.name} is a {self.species}"

            def _add_medical_record(self, record: str) -> None:
                self._medical_history.append(record)
                print(f"Medical record added for {self.name}")

            def __validate_contact(self, contact: str) -> bool:
                return "@" in contact and len(contact) > 5

            def update_owner_contact(self, new_contact: str) -> bool:
                if self._PetRecord__validate_contact(new_contact):
                    self.__owner_contact = new_contact
                    return True
                return False

        class VetRecord(PetRecord):
            def __init__(self, name: str, species: str, owner_contact: str, microchip_id: str):
                super().__init__(name, species, owner_contact, microchip_id)
                self._vet_notes = ""

            def add_vet_note(self, note: str) -> None:
                self._add_medical_record(f"Vet note: {note}")
                self._vet_notes = note

            def get_medical_summary(self) -> str:
                record_count = len(self._medical_history)
                return f"{self.name} has {record_count} medical records"

        if __name__ == "__main__":
            pet = PetRecord(
                name="Fluffy",
                species="cat",
                owner_contact="owner@example.com",
                microchip_id="123456789"
            )

            print(pet.get_basic_info())
            print(f"Pet name: {pet.name}")

            success = pet.update_owner_contact("new_owner@example.com")
            print(f"Contact updated: {success}")

            vet_record = VetRecord(
                name="Rex",
                species="dog",
                owner_contact="owner2@example.com",
                microchip_id="987654321"
            )

            vet_record.add_vet_note("Annual checkup - healthy")
            print(vet_record.get_medical_summary())
        ```

## Inheritance and Composition

!!! topic "Building Class Hierarchies"
    Jac supports both inheritance and composition patterns, making it easy to build flexible and maintainable class hierarchies.

### Simple Inheritance Example

!!! example "Pet Store Management System"
    === "Jac"
        <div class="code-block">
        ```jac
        obj Pet {
            has name: str;
            has species: str;
            has age: int;
            has is_adopted: bool = False;  # Automatic default

            def adopt() -> None {
                self.is_adopted = True;
                print(f"{self.name} has been adopted!");
            }

            def get_info() -> str {
                status = "adopted" if self.is_adopted else "available";
                return f"{self.name} is a {self.age}-year-old {self.species} ({status})";
            }
        }

        obj Employee {
            has name: str;
            has hire_date: str;
            has hourly_wage: float;

            def get_weekly_pay(hours: float) -> float {
                return hours * self.hourly_wage;
            }

            def introduce() -> str {
                return f"Hi, I'm {self.name}, an employee";
            }
        }

        obj Manager(Employee) {
            has department: str;
            has bonus_rate: float = 0.1;

            def get_weekly_pay(hours: float) -> float {
                # Override parent method
                base_pay = super.get_weekly_pay(hours);
                bonus = base_pay * self.bonus_rate;
                return base_pay + bonus;
            }

            def introduce() -> str {
                return f"Hi, I'm {self.name}, manager of {self.department}";
            }

            def conduct_meeting() -> None {
                print(f"{self.name} is conducting a {self.department} meeting");
            }
        }

        obj Veterinarian(Employee) {
            has license_number: str;
            has specialization: str = "general";

            def introduce() -> str {
                return f"Hi, I'm Dr. {self.name}, a {self.specialization} veterinarian";
            }

            def examine_pet(pet: Pet) -> str {
                print(f"Dr. {self.name} is examining {pet.name}");
                return f"{pet.name} appears healthy";
            }
        }

        with entry {
            # Create different types of employees
            manager = Manager(
                name="Sarah",
                hire_date="2023-01-15",
                hourly_wage=25.0,
                department="Pet Care"
            );

            vet = Veterinarian(
                name="Johnson",
                hire_date="2023-03-01",
                hourly_wage=45.0,
                license_number="VET-12345",
                specialization="small animals"
            );

            # Test polymorphism
            employees = [manager, vet];

            for employee in employees {
                print(employee.introduce());
                weekly_pay = employee.get_weekly_pay(40.0);
                print(f"  Weekly pay for 40 hours: ${weekly_pay}");
            }

            # Manager-specific behavior
            manager.conduct_meeting();

            # Vet-specific behavior
            pet = Pet(name="Buddy", species="dog", age=3);
            diagnosis = vet.examine_pet(pet);
            print(diagnosis);
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List

        class Employee:
            def __init__(self, name: str, hire_date: str, hourly_wage: float):
                self.name = name
                self.hire_date = hire_date
                self.hourly_wage = hourly_wage

            def get_weekly_pay(self, hours: float) -> float:
                return hours * self.hourly_wage

            def introduce(self) -> str:
                return f"Hi, I'm {self.name}, an employee"

        class Manager(Employee):
            def __init__(self, name: str, hire_date: str, hourly_wage: float, department: str, bonus_rate: float = 0.1):
                super().__init__(name, hire_date, hourly_wage)
                self.department = department
                self.bonus_rate = bonus_rate

            def get_weekly_pay(self, hours: float) -> float:
                base_pay = super().get_weekly_pay(hours)
                bonus = base_pay * self.bonus_rate
                return base_pay + bonus

            def introduce(self) -> str:
                return f"Hi, I'm {self.name}, manager of {self.department}"

            def conduct_meeting(self) -> None:
                print(f"{self.name} is conducting a {self.department} meeting")

        class Veterinarian(Employee):
            def __init__(self, name: str, hire_date: str, hourly_wage: float, license_number: str, specialization: str = "general"):
                super().__init__(name, hire_date, hourly_wage)
                self.license_number = license_number
                self.specialization = specialization

            def introduce(self) -> str:
                return f"Hi, I'm Dr. {self.name}, a {self.specialization} veterinarian"

            def examine_pet(self, pet) -> str:
                print(f"Dr. {self.name} is examining {pet.name}")
                return f"{pet.name} appears healthy"

        if __name__ == "__main__":
            manager = Manager(
                name="Sarah",
                hire_date="2023-01-15",
                hourly_wage=25.0,
                department="Pet Care"
            )

            vet = Veterinarian(
                name="Johnson",
                hire_date="2023-03-01",
                hourly_wage=45.0,
                license_number="VET-12345",
                specialization="small animals"
            )

            employees = [manager, vet]

            for employee in employees:
                print(employee.introduce())
                weekly_pay = employee.get_weekly_pay(40.0)
                print(f"  Weekly pay for 40 hours: ${weekly_pay:.2f}")

            manager.conduct_meeting()

            pet = Pet(name="Buddy", species="dog", age=3)
            diagnosis = vet.examine_pet(pet)
            print(diagnosis)
        ```

## Key Differences from Traditional OOP

!!! summary "Jac vs Traditional OOP"
    - **Automatic Constructors**: No need to write `__init__` methods
    - **Enforced Access Control**: `:pub`, `:priv`, `:protect` are actually enforced
    - **Clean Inheritance**: Automatic constructor chaining in inheritance
    - **Type Safety**: All method parameters and returns must be typed
    - **Implementation Separation**: Can separate interface from implementation

## Best Practices

!!! summary "Best Practices"
    1. **Use `obj` by Default**: Unless you need Python compatibility, prefer `obj` over `class`
    2. **Leverage Automatic Constructors**: Don't write manual constructors unless necessary
    3. **Use Access Control Meaningfully**: Make intentional decisions about public vs private
    4. **Favor Composition**: When inheritance gets complex, consider composition
    5. **Type Everything**: Explicit types make code more maintainable

## Key Takeaways

!!! summary "Chapter Summary"
    - **`obj` archetype** automatically generates constructors from `has` declarations
    - **Access control** is enforced at compile time, not just convention
    - **Inheritance** works naturally with automatic constructor chaining
    - **Type safety** is mandatory, preventing many runtime errors
    - **Less boilerplate** means more focus on business logic

Jac's enhanced OOP features eliminate much of the tedious boilerplate found in traditional object-oriented languages while providing better safety guarantees. This foundation prepares you for the revolutionary Object-Spatial Programming concepts we'll explore next, where these enhanced objects become spatially-aware nodes in a graph.

In the next chapter, we'll dive into the core innovation of Jac: Object-Spatial Programming and the paradigm shift from moving data to computation to moving computation to data.
