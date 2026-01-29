"""Minimal fixture for testing function-based tool extraction."""

import from byllm.lib { MockLLM, MockToolCall }

"""Calculate age from birth year."""
def calculate_age(birth_year: int, current_year: int) -> int {
    return current_year - birth_year;
}

sem calculate_age = "Calculate age from birth year.";
sem calculate_age.birth_year = "Year of birth.";
sem calculate_age.current_year = "Current year for calculation.";

"""Format a name as 'Last, First'."""
def format_name(first: str, last: str) -> str {
    return f"{last}, {first}";
}

sem format_name = "Format a name as 'Last, First'.";
sem format_name.first = "First name.";
sem format_name.last = "Last name.";

glob tool_llm = MockLLM(
    model_name="mockllm",
    config={
        "outputs": [
            MockToolCall(tool=calculate_age, args={"birth_year": 1990, "current_year": 2025}),
            "The person is 35 years old."
        ],
        "verbose": False
    }
);

"""Get person details using tools."""
def get_person_details(birth_year: int) -> str by tool_llm(tools=[calculate_age, format_name]);

sem get_person_details = "Get detailed person information using helper tools.";
sem get_person_details.birth_year = "Birth year to calculate age from.";
