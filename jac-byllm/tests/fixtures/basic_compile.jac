"""Minimal fixture to verify basic MTIR compilation works."""

import from byllm.lib { MockLLM }

"""A simple person."""
obj Person {
    has name: str,
        age: int;
}

sem Person = "A person entity.";
sem Person.name = "The person's name.";
sem Person.age = "The person's age.";

glob mock_person = Person(name="Test", age=30);

glob simple_llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [mock_person], "verbose": False}
);

"""Generate a person."""
def generate_person(criteria: str) -> Person by simple_llm();

sem generate_person = "Generate a person matching criteria.";
sem generate_person.criteria = "Description of the person to generate.";
