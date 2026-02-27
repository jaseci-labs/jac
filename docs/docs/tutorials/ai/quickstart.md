# byLLM Quickstart

Build your first AI-integrated function in Jac.

> **Prerequisites**
>
> - Completed: [Installation](../../quick-guide/install.md)
> - Jac installed with `pip install jaseci`
> - An API key from OpenAI, Anthropic, or Google
> - Time: ~20 minutes

---

## Setup

### 1. Install byLLM

If you haven't already:

```bash
pip install byllm
```

### 2. Set Your API Key

```bash
# OpenAI
export OPENAI_API_KEY="sk-..."

# Or Anthropic
export ANTHROPIC_API_KEY="sk-ant-..."

# Or Google
export GOOGLE_API_KEY="..."
```

---

## Your First AI Function

Create `hello_ai.jac`:

```jac
def translate2french(text: str) -> str by llm();
sem translate2french = "Translate the given text to French";

with entry {
    result = translate2french("Hello, how are you?");
    print(result);
}
```

!!! tip "Zero-config `llm`"
    `llm` is a **built-in** name -- no imports required. By default it uses `gpt-4o-mini` configured via your `jac.toml` (see [Configuration via jac.toml](#configuration-via-jactoml) below).

Run it:

```bash
jac hello_ai.jac
```

**Output:**

```
Bonjour, comment allez-vous ?
```

---

## How It Works

The key is the `by llm()` syntax:

```jac
def translate2french(text: str) -> str by llm();
```

| Part | Purpose |
|------|---------|
| `translate2french` | Function name conveys the intent |
| `(text: str)` | Input parameter with descriptive name and type |
| `-> str` | Expected return type |
| `by llm()` | Delegates implementation to the LLM |

The compiler extracts semantics from the code -- function name, parameter names, types, and return type -- and uses them to construct the LLM prompt.

### sem keyword

Use the `sem` keyword to attach semantic descriptions to types, fields, functions, and parameters. These semantic strings are included in the compiler-generated prompt so the LLM sees them at runtime. Prefer `sem` for machine-readable guidance rather than embedding instructions in docstrings.

Examples:

```jac
# Attach semantics to a function
sem translate = "Translate the given text to French. Preserve formatting and tone.";
def translate(text: str) -> str by llm();

# Attach semantics to a function parameter
sem translate.text = "Short, plain-language input text to translate.";

# Attach semantics to a type field
obj Product { has price: float; }
sem Product.price = "Price in USD, numeric value";

# Attach semantics to an enum value
enum Priority { LOW, MEDIUM, HIGH }
sem Priority.HIGH = "Urgent: requires immediate attention";
```

!!! tip "Best practice"
    Always use `sem` to provide context for `by llm()` functions. Docstrings are intended for human documentation (and auto-generated API docs) but are **not** included in compiler-generated prompts. Only `sem` declarations affect LLM behavior.

---

## Different Providers

byLLM uses [LiteLLM](https://docs.litellm.ai/docs/providers) under the hood, giving you access to 100+ model providers. Set the model in your `jac.toml`:

=== "OpenAI"
    ```toml
    [plugins.byllm.model]
    default_model = "gpt-4o-mini"
    ```
    ```bash
    export OPENAI_API_KEY="sk-..."
    ```

=== "Anthropic"
    ```toml
    [plugins.byllm.model]
    default_model = "claude-sonnet-4-6"
    ```
    ```bash
    export ANTHROPIC_API_KEY="sk-ant-..."
    ```

=== "Google"
    ```toml
    [plugins.byllm.model]
    default_model = "gemini/gemini-2.0-flash"
    ```
    ```bash
    export GOOGLE_API_KEY="..."
    ```

=== "Ollama (Local)"
    ```toml
    [plugins.byllm.model]
    default_model = "ollama/llama3:70b"
    ```
    No API key needed - runs locally. See [Ollama](https://ollama.ai/) for setup.

=== "HuggingFace"
    ```toml
    [plugins.byllm.model]
    default_model = "huggingface/meta-llama/Llama-3.3-70B-Instruct"
    ```
    ```bash
    export HUGGINGFACE_API_KEY="hf_..."
    ```

You can also override the model per-file when needed:

```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4o");  # overrides the builtin for this file
```

For model name formats, configuration options, and 100+ additional providers (Azure, AWS Bedrock, Vertex AI, Groq, etc.), see the [byLLM Reference](../../reference/plugins/byllm.md#supported-providers) and [LiteLLM documentation](https://docs.litellm.ai/docs/providers).

!!! tip "Model names change"
    AI model names are updated regularly by providers. If an example's model name returns a "not found" error, check the provider's documentation for current model names. The `by llm()` syntax works with any model supported by [LiteLLM](https://docs.litellm.ai/docs/providers).

---

## Controlling the AI

### Temperature

Control creativity (0.0 = deterministic, higher = more creative):

!!! note "Provider-Specific Limits"
    Temperature range varies by provider: Anthropic supports 0.0–1.0, OpenAI supports 0.0–2.0. Use a value within your provider's range.

```jac
def write_story(topic: str) -> str by llm(temperature=0.9);

def extract_facts(text: str) -> str by llm(temperature=0.0);
```

---

## Practical Examples

### Sentiment Analysis

```jac
enum Sentiment {
    POSITIVE,
    NEGATIVE,
    NEUTRAL
}

def analyze_sentiment(text: str) -> Sentiment by llm();

with entry {
    texts = [
        "I love this product! It's amazing!",
        "This is the worst experience ever.",
        "The package arrived on Tuesday."
    ];

    for text in texts {
        sentiment = analyze_sentiment(text);
        print(f"{sentiment}: {text[:40]}...");
    }
}
```

### Text Summarization

```jac
def summarize(article: str) -> str by llm();

sem summarize = "Summarize this article in 2-3 bullet points.";

with entry {
    article = """
    Artificial intelligence has made remarkable progress in recent years.
    Large language models can now write code, answer questions, and even
    create art. However, challenges remain around safety, bias, and
    environmental impact. Researchers are actively working on solutions.
    """;

    summary = summarize(article);
    print(summary);
}
```

### Code Generation

```jac
def generate_code(description: str) -> str by llm();

sem generate_code = "Generate a Python function based on the description.";

with entry {
    desc = "A function that checks if a string is a palindrome";
    code = generate_code(desc);
    print(code);
}
```

---

## Configuration via jac.toml

Control model, parameters, and system prompt in `jac.toml`:

```toml
[plugins.byllm.model]
default_model = "gpt-4o-mini"       # any LiteLLM-supported model

[plugins.byllm.call_params]
temperature = 0.7

[plugins.byllm]
system_prompt = "You are a helpful assistant."
```

This applies to all `by llm()` functions, providing consistent behavior without repeating configuration in code.

**Advanced:** For custom/self-hosted models with HTTP client, see [byLLM Reference](../../reference/plugins/byllm.md#project-configuration).

---

## Error Handling

```jac
def translate2spanish(text: str) -> str by llm();

with entry {
    try {
        result = translate2spanish("Hello");
        print(result);
    } except Exception as e {
        print(f"AI call failed: {e}");
    }
}
```

---

## Testing AI Functions

Use MockLLM for deterministic tests:

```jac
import from byllm.lib { MockLLM }

glob llm = MockLLM(
    model_name="mockllm",
    config={
        "outputs": ["Mocked response 1", "Mocked response 2"]
    }
);

def translate(text: str) -> str by llm();

test "translate" {
    result = translate("Hello");
    assert result == "Mocked response 1";
}
```

---

## Key Takeaways

| Concept | Syntax |
|---------|--------|
| Configure LLM | `jac.toml` `[plugins.byllm.model]` or `glob llm = Model(...)` |
| AI function | `def func() -> Type by llm()` |
| Semantic context | `sem func = "..."` |
| Type safety | Return type annotation |
| Temperature | `by llm(temperature=0.5)` |
| Max tokens | `by llm(max_tokens=100)` |

---

## Next Steps

- [Structured Outputs](structured-outputs.md) - Return enums, objects, and lists
- [Agentic AI](agentic.md) - Tool calling and ReAct patterns
- [Build an AI Day Planner](../first-app/build-ai-day-planner.md#part-5-making-it-smart-with-ai) - See AI integration in a complete full-stack app
- [byLLM Reference](../../reference/plugins/byllm.md) - Complete documentation
