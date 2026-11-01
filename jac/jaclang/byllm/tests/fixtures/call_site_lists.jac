"""By-llm call sites whose MTIR carries params, tools and an obj's fields."""

import from jaclang.byllm.lib { MockLLM }

obj Person {
    has name: str,
        age: int;
}

def lookup(query: str) -> str {
    return query;
}

glob lists_llm = MockLLM(model_name="mockllm", outputs=["Ada"]);

def describe(text: str, limit: int) -> str by lists_llm(tools=[lookup]);

sem describe.text = "Text to describe.";

def make_person(hint: str) -> Person by lists_llm();
