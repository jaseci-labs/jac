import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini", config={"verbose": True});

"""Personality types for classification."""
enum Personality {
    INTROVERT = 1,
    EXTROVERT = 2,
    AMBIVERT = 3
}

sem Personality.INTROVERT =
"Person who is reserved, reflective, and prefers solitude.";

sem Personality.EXTROVERT =
"Person who is outgoing, socially confident, and energized by interaction.";

sem Personality.AMBIVERT =
"Person who shows a balance of introverted and extroverted traits.";

"""Status codes for operations."""
enum Status {
    PENDING = "pending",
    ACTIVE = "active",
    COMPLETED = "completed"
}

sem Status.PENDING = "Operation is waiting to start.";
sem Status.ACTIVE = "Operation is currently running.";
sem Status.COMPLETED = "Operation has finished successfully.";

"""Simple enum without explicit values."""
enum Color { RED, GREEN, BLUE }

"""Person with personality classification."""
obj Person {
    has full_name: str,
        personality: Personality,
        status: Status;
}

sem Person.personality = "The personality type of the person.";
sem Person.status = "The current status of the person.";

"""Extract person information from description."""
def get_person_info(name: str) -> Person by llm(
    reason=True,
    temperature=0.0
);
