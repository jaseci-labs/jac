"""Test fixture for MTIR generation pass.

This file tests that the MTIR pass correctly extracts type information
from GenAI abilities, including:
- Simple types (primitives)
- Complex types (custom classes)
- Nested types (list[T], dict[K,V])
- Semstrings
- Method parameters and return types
"""

# Mock LLM object for testing - doesn't need to be a real LLM
# The MTIR pass only cares about the structure, not execution
obj MockLLM {
    def __call__(**kwargs: dict) -> MockLLM {
        return self;
    }
}

glob llm = MockLLM();

# Simple class for testing basic type extraction
obj Person {
    has name: str,
        age: int;
}

# Class with nested type references
obj Team {
    has id: int,
        members: list[Person],
        metadata: dict[str, str];
}

# Class with complex nested types
obj Project {
    has name: str,
        team: Team,
        tags: list[str];

    # GenAI method that returns same class type
    def summarize(query: str) -> Project by llm();
}

# Standalone GenAI function
def analyze_person(person: Person, detail_level: int) -> str by llm();

# GenAI function with complex return type
def create_team(name: str, size: int) -> Team by llm();

# GenAI function with list return type
def find_people(criteria: str) -> list[Person] by llm();

# Add semstrings for testing semstring extraction
sem Person = "A person with a name and age.";
sem Person.name = "The person's full name.";
sem Person.age = "The person's age in years.";

sem Team = "A team consisting of multiple people.";
sem Team.members = "List of team members.";

sem Project = "A project with a team and metadata.";
sem Project.summarize = "Summarize the project based on a query.";
sem Project.summarize.query = "The query to summarize.";

sem analyze_person = "Analyze a person's profile.";
sem analyze_person.person = "The person to analyze.";
sem analyze_person.detail_level = "Level of detail (1-5).";
