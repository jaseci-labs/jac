"""Child node inheriting an imported parent + a `by llm(tools=[...])` method."""

import from parent { Parent }

obj MockLLM {
    def __call__(**kwargs: dict) -> MockLLM {
        return self;
    }
}

glob llm = MockLLM();

def helper_tool(q: str) -> str {
    return q;
}

node Child(Parent) {
    def step(q: str) -> str by llm(tools=[helper_tool]);
}
