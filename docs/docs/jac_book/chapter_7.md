# Chapter 7: Enhanced OOP - Objects and Classes
---

Jac fully supports the principles of Object-Oriented Programming (OOP) but enhances them to be more intuitive and efficient. This chapter will guide you through using Jac's obj archetype to create well-structured, maintainable, and powerful objects.

Jac simplifies the object creation process by providing features like **automatic constructors**, **implementation separation**, and **improved access control**, which reduce boilerplate code and allow you to focus more on the logic of your application.


## Jac `obj` Archetype
---

In Jac, you define a blueprint for an object using the `obj` archetype, which serves a similar purpose to the class keyword in Python. An `obj` bundles data (attributes) and behavior (methods) into a single, self-contained unit.

Let's define a `Pet` object to see how this works.

```jac
obj Pet {
    # 1. Define attributes with the 'has' keyword.
    has name: str;
    has species: str;
    has age: int;
    has is_adopted: bool = False;  # Automatic default

    # 2. Define methods with the 'def' keyword.
    # Methods use 'self' to access the object's own attributes.
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
    # 3. Create an instance using the automatic constructor.
    pet = Pet(name="Buddy", species="dog", age=3);
    print(pet.get_info());
    pet.adopt();
}
```
<br />

Let's break down the key features demonstrated in this example.

1. Defining Attributes with `has`: The `has` keyword is used to declare the data fields (attributes) that each Pet object will hold. You must provide a type for each attribute, and you can optionally set a default value, like `is_adopted: bool = False`.
2. The Automatic Constructor: Notice that we did not have to write an __init__ method. Jac automatically generates a constructor for you based on the attributes you declare with has. This saves you from writing repetitive boilerplate code and allows you to create a new Pet instance with a clean and direct syntax: `Pet(name="Buddy", species="dog", age=3)`.


### Advanced Constructor Features

Sometimes, you need to run logic after an object's initial attributes have been set. For this, Jac provides the `postinit` method. This is useful for calculated properties or for validation that depends on multiple attributes.
To use it, you declare an attribute with the by `postinit` modifier. This signals that the attribute exists, but its value will be assigned within the `postinit` method.
Let's enhance our pet shop example. We'll create a PetShop object and use `postinit` to automatically set its is_open status based on whether it has reached its capacity.


```jac
obj PetShop {
    # Attributes set by the automatic constructor
    has name: str;
    has pets: list[Pet] = [];
    has capacity: int = 10;
    # This attribute's value will be calculated after initialization.
    has is_open: bool by postinit;

     # This method runs automatically after the object is created
    def postinit() -> None {
        # This logic determines the value of 'is_open'.
        self.is_open = len(self.pets) < self.capacity;
        print(f"{self.name} shop initialized with {len(self.pets)} pets");
    }
}
```
<br />

## Object Inheritance
---
Inheritance is a fundamental concept in OOP that allows you to create a new, specialized object based on an existing one. The new object, or subclass, inherits all the attributes and methods of the parent object, and can add its own unique features or override existing ones. This promotes code reuse and helps create a logical hierarchy.

### Simple Inheritance Example

```jac
obj Animal {
    has name: str;
    has species: str;
    has age: int;

    def make_sound() -> None {
        print(f"{self.name} makes a sound.");
    }
}
# A subclass that inherits from Animal
obj Dog(Animal) {
    has breed: str;

    def make_sound() -> None {
        print(f"{self.name} barks.");
    }
}

obj Cat(Animal) {
    has color: str;

    def make_sound() -> None {
        print(f"{self.name} meows.");
    }
}
```
<br />
In this example, both `Dog` and `Cat` automatically have the `name`, `species`, and `age` attributes from Animal. However, they each provide a specialized version of the `make_sound` method, demonstrating polymorphism.

## Access Control with `:pub`, `:priv`, `:protect`
---
To create robust and secure objects, it is important to control which of their attributes and methods can be accessed from outside the object's own code. This principle is called encapsulation. Unlike Python, Jac provides explicit keywords that are enforced by the runtime.

### Public Access
Public members are accessible from anywhere. This is the default behavior in Jac, so the `:pub` keyword is optional but can be used for clarity.

```jac
obj PublicExample {
    # This attribute is public by default.
    has :pub public_property: str;

    # Explicitly marking a method as public.
    def :pub public_method() -> str {
        return "This is a public method";
    }
}
with entry {
    example = PublicExample(public_property="Hello");
    # Both are accessible from outside the object.
    print(example.public_method());
    print(example.public_property);
}
```
<br />

### Private Access
Private members, marked with `:priv`, can only be accessed from within the object itself. Any attempt to access a private member from outside code will result in an error. This is essential for protecting an object's internal state.

```jac
obj PrivateExample {
    has :priv private_property: str;
    has :priv another_private_property: int = 42;

    def :priv private_method() -> str {
        return "This is a private method";
    }

    def :pub public_method() -> str {
        return self.private_method();
    }
}
with entry {
    example = PrivateExample(private_property="Secret");
    print(example.public_method());
    # print(example.private_property);  # This would raise an error
}
```
<br />

### Protected Access
Protected members, marked with `:protect`, create a middle ground between public and private. They are accessible within the object that defines them and within any of its subclasses. This is useful for creating internal logic that you want to share across a family of related objects but still keep hidden from the outside world.

```jac
obj ProtectedExample {

    has :protect protected_property: str = "Protected";
    has :protect protected_list: list[int] = [];
    has :protect protected_dict: dict[str, int] = {"key": 1};

    def :protect protected_method() -> str {
        return "This is a protected method";
    }
}
obj SubProtectedExample(ProtectedExample) {
    def :pub public_method() -> str {
        return self.protected_method();
    }
}
with entry {
    example = SubProtectedExample();
    print(example.public_method());
    print(example.protected_property);
    print(example.protected_list);
    print(example.protected_dict);
}
```
<br />


### Example: Pet Record System

Let's combine these access control concepts into a practical example. We will build a `PetRecord` object that securely manages a pet's information.

- Public information, like the pet's name, will be freely accessible.
- Protected information, like medical history, will be accessible only to specialized subclasses like a VetRecord.
- Private information, like the owner's contact details, will be strictly controlled by the object itself.


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
<br />



## Key Differences from Python OOP
- **Automatic Constructors**: No need to write `__init__` methods
- **Enforced Access Control**: `:pub`, `:priv`, `:protect` are actually enforced
- **Clean Inheritance**: Automatic constructor chaining in inheritance
- **Type Safety**: All method parameters and returns must be typed
- **Implementation Separation**: Can separate interface from implementation


## Wrapping Up
---

In this chapter, you've learned how Jac builds upon classic Object-Oriented Programming with features that promote cleaner, safer, and more maintainable code. You now have the tools to create robust, well-structured objects with automatic constructors, enforced access control, and clear inheritance.

These concepts form the foundation upon which Jac's most powerful paradigm is built. In the next chapter, we will make the leap from Object-Oriented to Object-Spatial Programming (OSP). We will see how these objects are extended into nodes that can exist in a graph, giving them a spatial context and unlocking a new way to handle complex, interconnected data.

---

*You now have powerful object-oriented tools at your disposal. Let's discover how OSP takes these concepts to the next level!*
