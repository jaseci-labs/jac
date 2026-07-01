# I like to build … AI agents & LLM apps

Weave LLMs into your code at the language level. `by llm()` turns a function's name, types, and `sem` annotations into the prompt automatically -- no prompt strings, no response parsing. This track is also a **capability you add to any other track**: a CLI, a backend, a full-stack app, or a desktop build can all become AI-powered the same way.

## Your 5-minute quick win {#ai}

Declare *what* you want through a function signature and let the compiler handle the *how*. The return type is the output contract:

```jac
# The function name, types, and return type ARE the specification
def classify_sentiment(text: str) -> str by llm();

# Enums constrain the LLM to valid outputs
enum Priority { LOW, MEDIUM, HIGH, CRITICAL }
def triage_ticket(description: str) -> Priority by llm();

# obj return types mean every field must be filled -- structured output, no parsing
obj Ingredient { has name: str, cost: float; }
sem Ingredient.cost = "Estimated cost in USD";
def plan_shopping(recipe: str) -> list[Ingredient] by llm();
```

Enable byLLM and pick a model in `jac.toml`, then run any program that calls these:

```bash
jac install byllm
export ANTHROPIC_API_KEY="your-key-here"   # or any LiteLLM-compatible provider
```

```toml
[plugins.byllm.model]
default_model = "claude-sonnet-4-20250514"   # gemini/gemini-2.5-flash for a free option
```

For **agentic** workflows, give the LLM tools and let it decide which to call:

```jac
def answer_question(question: str) -> str
    by llm(tools=[get_weather, search_web]);
```

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- how `by`/`sem` turn prompting into a compiler problem
- **Build it for real** → [Your First AI Function](../tutorials/ai/quickstart.md) · [Structured Outputs](../tutorials/ai/structured-outputs.md) · [Agentic AI](../tutorials/ai/agentic.md) · [Multimodal](../tutorials/ai/multimodal.md)
- **Look it up** → [byLLM reference](../reference/plugins/byllm.md) · [Agentic patterns](../reference/plugins/byllm.md#agentic-ai-patterns)
- **Local models** → [Built-in local models](../reference/plugins/byllm.md#built-in-local-models)

## Going further -- add AI to anything

- An AI CLI tool → [CLI tools & native binaries](cli-and-native.md)
- An AI backend → [Backend APIs & services](backend-apis.md)
- An AI full-stack app → [Full-stack web apps](fullstack-web.md) (see the AI Day Planner)
