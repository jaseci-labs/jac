"""Fixture with module name ending in 'j' to test scope name resolution."""

import from byllm.lib { MockLLM }

obj Project {
    has title: str;
}

glob llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [Project(title="test_project")], "verbose": False}
);

def create_proj -> Project by llm();
