---
name: jac-by-llm
description: Delegating a function's body to an LLM call - structured outputs, tool use, prompt wiring. Load when any function or method should be powered by an LLM instead of hand-written logic. Pair with `jac-walker-patterns` when LLMs drive graph agents.
---

`by llm(...)` replaces a function body with an LLM call. The signature declares typed args and a return type; at call time the LLM generates a value matching the return type, optionally using any functions listed in `tools=[...]` as ReAct helpers. Describe every LLM-visible thing - the function itself, each parameter, each field of a return obj - with `sem` statements, not docstrings. `sem` is the prompt the LLM sees.

```jac
import from byllm.lib { Model }

glob llm: Model = Model(model_name="gpt-4o");

obj Summary {
    has title: str;
    has bullets: list[str];
}

sem Summary.title   = "A short, specific title capturing the text's topic.";
sem Summary.bullets = "Key points - each a single concise sentence.";


def word_count(text: str) -> int {
    return len(text.split());
}

sem word_count      = "Count whitespace-separated words in text.";
sem word_count.text = "The text to count words in.";


def summarize(text: str) -> Summary by llm(temperature=0.2, max_tokens=500);

sem summarize      = "Extract a structured Summary from the given text.";
sem summarize.text = "The text to summarize.";


def analyze(question: str) -> str by llm(
    tools=[word_count],
    temperature=0.2,
    max_react_iterations=5
);

sem analyze          = "Answer a question. May call word_count as a tool.";
sem analyze.question = "The question to answer.";


with entry {
    s = summarize("Jac is a graph-native language.");
    print(s.title);
    print(analyze("How many words in 'hello world'?"));
}
```

## Pitfalls

- `llm` is an **ambient builtin** - the model powering it is configured project-wide in `jac.toml` under `[plugins.byllm.model]` (e.g. `default_model = "gpt-4o-mini"`). A module-level `glob llm: Model = Model(...)` (as shown above) is an *optional* per-file override, not a requirement: `by llm()` type-checks and runs with no `glob llm` declared at all.
- `by llm(...)` REPLACES the body - never write both `{ body }` and `by llm(...)` on the same signature.
- Use `sem`, NOT docstrings, for every LLM-visible description. Triple-quoted strings inside a body fail with W0060.
- Tools are **function references**, NOT strings: `tools=[word_count]`, never `tools=["word_count"]`. Each tool needs its own `sem` and per-arg `sem` so the LLM knows when to call it.
- Common `by llm(...)` options: `tools`, `temperature`, `max_tokens`, `max_react_iterations`, `conversation` (multi-turn history), `on_iteration` (ReAct loop control), `stream`, `incl_info` - and more; see the byLLM reference for the full list. The model is normally selected by `jac.toml` / the `Model` instance, not a per-call argument. Note: `jac check` does **not** validate `by llm` keyword names, so a misspelled option surfaces at runtime, not at check time.
