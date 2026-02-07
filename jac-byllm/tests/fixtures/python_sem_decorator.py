"""Test fixture for Python sem decorator usage.

Verifies that semantic strings attached via the @sem decorator
end up in the LLM prompt (user message and response schema).
"""

from dataclasses import dataclass

from byllm.lib import MockLLM, by, sem


@sem("A customer record in the CRM system")
@dataclass
class Customer:
    name: str
    tier: str


llm_extract = MockLLM(
    model_name="mockllm",
    config={
        "verbose": True,
        "show_params": True,
        "outputs": [Customer(name="Alice Smith", tier="premium")],
    },
)

llm_greet = MockLLM(
    model_name="mockllm",
    config={
        "verbose": True,
        "show_params": True,
        "outputs": ["Hello, Alice! Welcome back, valued premium member."],
    },
)


@by(llm_extract)
@sem("Extract customer information from the given text")
def extract_customer(text: str) -> Customer: ...


@by(llm_greet)
@sem("Generate a personalized greeting based on the customer's tier and name")
def greet_customer(customer: Customer, formal: bool) -> str: ...


def test_sem_in_prompt() -> dict:
    """Run functions and return captured params output."""
    customer = extract_customer(text="Alice Smith is a premium enterprise customer")
    greeting = greet_customer(customer=customer, formal=True)
    return {"customer": customer, "greeting": greeting}


def test_tool_sem_description() -> dict:
    """Verify that @sem on a function sets _jac_semstr for tool descriptions."""

    @sem(
        "Look up a customer by their ID in the database",
        {"customer_id": "The unique customer identifier (UUID format)"},
    )
    def lookup_customer(customer_id: str) -> Customer:
        return Customer(name="Alice Smith", tier="premium")

    from byllm.types import Tool

    tool = Tool(func=lookup_customer)
    schema = tool.get_json_schema()
    return {
        "description": tool.description,
        "schema": schema,
    }


if __name__ == "__main__":
    result = test_sem_in_prompt()
    print(f"Customer: {result['customer']}")
    print(f"Greeting: {result['greeting']}")
