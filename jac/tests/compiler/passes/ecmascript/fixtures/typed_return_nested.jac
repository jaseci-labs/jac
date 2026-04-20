"""Fixture: SV returns nested typed objects to CL.

Tests that nested obj types (obj containing another obj)
are handled correctly across the codespace boundary.
"""

obj Address {
    has street: str,
        city: str,
        zip_code: str;
}

obj Person {
    has name: str,
        age: int,
        address: Address;
}

def:pub get_person(name: str) -> Person {
    return Person(
        name=name,
        age=30,
        address=Address(street="123 Main St", city="Springfield", zip_code="62704")
    );
}

def:pub list_people -> list[Person] {
    return [
        Person(name="Alice", age=30, address=Address(street="1st", city="A", zip_code="111")),
        Person(name="Bob", age=25, address=Address(street="2nd", city="B", zip_code="222"))
    ];
}

cl {
    sv import from .typed_return_nested { get_person, list_people }

    def:pub app -> JsxElement {
        has person: Any = None,
            loading: bool = True;

        async can with entry {
            person = await get_person("Alice");
            loading = False;
        }

        return <div>
            <span>{person.name} lives at {person.address.city}</span>
        </div>;
    }
}
