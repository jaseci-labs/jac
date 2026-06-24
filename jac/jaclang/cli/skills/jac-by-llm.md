---
name: jac-by-llm
description: Delegating a function's body to an LLM call - structured outputs (objects, enums, lists), tool use/ReAct agents, model & provider configuration (API keys, Ollama/local), multi-turn chat, streaming, image/video inputs, MockLLM testing, prompt wiring via sem. Load when any function should be powered by an LLM. Pair with jac-walker-patterns when LLMs drive graph agents, jac-testing for MockLLM tests.
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

## Classification, extraction, methods

```jac
enum Priority { LOW, MEDIUM, HIGH }
sem Priority.HIGH = "Urgent: requires immediate attention.";   # member semstrings go into the LLM's schema
def classify(ticket: str) -> Priority by llm();

enum HttpStatus: int { OK = 200, NOT_FOUND = 404 }   # typed-base enum: members ARE ints - no .value at call sites
def status_for(description: str) -> HttpStatus by llm();

def extract_tasks(notes: str) -> list[Task] by llm();   # lists, nested objs work; `-> T | None` lets the LLM say "not found"

obj Account {
    has owner: str;
    has balance: float = 0.0;
    def deposit(amount: float) -> float { self.balance += amount; return self.balance; }
    def advise(question: str) -> str by llm(tools=[self.deposit]);  # bound methods work as tools
}
```

Method-level `by llm` automatically includes the object's `has` fields as context - no need to pass `self.owner` etc. as arguments. LLM return types are `obj`s, never `node`s: have the LLM fill an `obj`, then copy fields into a `node` to persist - the AI schema and the storage schema evolve independently.

## Models & providers

| Provider | `model_name` format | Auth |
|---|---|---|
| OpenAI | `gpt-4o`, `gpt-4o-mini` | `OPENAI_API_KEY` |
| Anthropic | `claude-sonnet-4-6` | `ANTHROPIC_API_KEY` |
| Google | `gemini/gemini-2.0-flash` | `GOOGLE_API_KEY` |
| Ollama | `ollama/llama3:70b` | none - local daemon |
| Built-in local | `local:gemma-4-e4b` | none - `jac install 'byllm[local]'`, then `jac model pull gemma-4-e4b` |

Env vars take precedence over `api_key` in `jac.toml`; `BYLLM_DEFAULT_MODEL=...` overrides the project default for one shell. The glob name needn't be `llm` - any module-level glob holding a `Model` works: `glob fast = Model(model_name="gpt-4o-mini"); def quick_label(text: str) -> str by fast();`.

## Multi-turn chat & streaming

```jac
glob history: list[dict] = [];
def chat(message: str) -> str by llm(
    conversation=history,                        # caller-owned list; byLLM appends each turn IN PLACE as plain dicts
    system_prompt="You are a terse assistant."   # EXTENDS the base/system default - never replaces it
);

def stream_story(topic: str) -> str by llm(stream=True);
# stream=True returns a GENERATOR: for token in stream_story("space") { print(token, end=""); }
# str returns only - any other return type raises ConfigurationError at call time.
```

## Testing with MockLLM

Runs without API keys - mock outputs are consumed sequentially, one per `by` call. For typed returns put pre-built instances in `outputs` (e.g. `Priority.HIGH`, `[Task(...)]`). See `jac-testing` for `jac test` mechanics.

```jac
import from byllm.lib { MockLLM }

glob llm = MockLLM(model_name="mockllm", config={"outputs": ["Bonjour", "Salut"]});

def translate(text: str) -> str by llm();

test "mock outputs consumed in order" {
    assert translate("Hello") == "Bonjour";
    assert translate("Hi") == "Salut";
}
```

## Errors & retries

- All byLLM exceptions inherit `ByLLMError`, importable from `byllm.lib`: `AuthenticationError`, `RateLimitError`, `ModelNotFoundError`, `OutputConversionError`, `UnknownToolError`, `ConfigurationError`.
- Typed (non-`str`) returns auto-retry malformed output with corrective feedback: `max_output_retries` (default 3, `0` disables). `str` returns are never retried.
- The rejected text rides on `OutputConversionError` - read it with `getattr(e, "raw_output", "")`; direct `e.raw_output` fails `jac check` (E1030, it's a dynamic attribute).

## Images & video

```jac
import from byllm.lib { Image, Video }

def parse_receipt(img: Image) -> Receipt by llm();   # structured output straight from an image
def describe_clip(v: Video) -> str by llm();

# Call as parse_receipt(Image("receipt.jpg")) - Image also accepts URLs, raw bytes, PIL images.
# Video(path="clip.mp4", fps=1): fps = frames sampled/sec; needs `jac install 'byllm[video]'`.
# Requires a vision-capable model (e.g. gpt-4o, claude-sonnet-4-6).
```

## Pitfalls

- Inline `by llm` expressions DO NOT exist: `x = "prompt" by llm;` even passes `jac check`, then raises `NotImplementedError` at runtime. Always declare a function and call it.
- `method="ReAct"` is deprecated and was never functional - the ReAct loop turns on automatically when you pass `tools=[...]`.
- `llm` is an **ambient builtin** - the model powering it is configured project-wide in `jac.toml` under `[plugins.byllm.model]` (e.g. `default_model = "gpt-4o-mini"`). A module-level `glob llm: Model = Model(...)` is an *optional* per-file override, not a requirement: `by llm()` type-checks and runs with no `glob llm` declared at all.
- `by llm(...)` REPLACES the body - never write both `{ body }` and `by llm(...)` on the same signature.
- Use `sem`, NOT docstrings, for every LLM-visible description. Triple-quoted strings inside a body fail with W0060.
- Tools are **function references**, NOT strings: `tools=[word_count]`, never `tools=["word_count"]`. Each tool needs its own `sem` and per-arg `sem` so the LLM knows when to call it.
- Common `by llm(...)` options: `tools`, `temperature`, `max_tokens`, `max_react_iterations`, `conversation`, `system_prompt`, `stream`, `incl_info` (extra context dict), `on_iteration` (ReAct loop control), `max_output_retries`. `jac check` does **not** validate `by llm` keyword names - a misspelled option surfaces at runtime, not at check time.
- For fallback/load-balancing across several providers, see `ModelPool` in the byLLM reference; project-wide `temperature`/`max_tokens` defaults live in `jac.toml` under `[plugins.byllm.call_params]`.
