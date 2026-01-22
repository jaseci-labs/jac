# byLLM Quickstart

Build your first AI-integrated function in Jac.

**Time:** 20 minutes

---

## Prerequisites

- Jac installed with `pip install jaseci`
- An API key from OpenAI, Anthropic, or Google

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
import from byllm.lib { Model }

# Configure the LLM
glob llm = Model(model_name="gpt-4o-mini");

"""Translate the given text to French."""
def translate(text: str) -> str by llm();

with entry {
    result = translate("Hello, how are you?");
    print(result);
}
```

Run it:

```bash
jac run hello_ai.jac
```

**Output:**

```
Bonjour, comment allez-vous ?
```

---

## How It Works

The magic is in the `by llm()` syntax:

```jac
"""Translate the given text to French."""
def translate(text: str) -> str by llm();
```

| Part | Purpose |
|------|---------|
| `"""..."""` | Docstring becomes the AI prompt |
| `(text: str)` | Input parameter with type |
| `-> str` | Expected return type |
| `by llm()` | Delegates implementation to the LLM |

**byLLM automatically:**

1. Generates a prompt from the docstring and type signature
2. Calls the LLM API
3. Parses the response into the correct return type

No manual prompt engineering needed!

---

## Different Providers

### OpenAI

```jac
glob llm = Model(model_name="gpt-4o-mini");
glob llm = Model(model_name="gpt-4o");
glob llm = Model(model_name="gpt-4");
```

### Anthropic

```jac
glob llm = Model(model_name="claude-3-5-sonnet-20241022");
glob llm = Model(model_name="claude-3-opus-20240229");
glob llm = Model(model_name="claude-3-haiku-20240307");
```

### Google

```jac
glob llm = Model(model_name="gemini/gemini-2.0-flash");
glob llm = Model(model_name="gemini/gemini-pro");
```

---

## Controlling the AI

### Temperature

Control creativity (0.0 = deterministic, 2.0 = very creative):

```jac
"""Write a creative story about a robot."""
def write_story(topic: str) -> str by llm(temperature=1.5);

"""Extract the main facts from this text."""
def extract_facts(text: str) -> str by llm(temperature=0.0);
```

### Max Tokens

Limit response length:

```jac
"""Summarize in one sentence."""
def summarize(text: str) -> str by llm(max_tokens=100);
```

---

## Practical Examples

### Sentiment Analysis

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

enum Sentiment {
    POSITIVE,
    NEGATIVE,
    NEUTRAL
}

"""Analyze the sentiment of this text."""
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
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

"""Summarize this article in 2-3 bullet points."""
def summarize(article: str) -> str by llm();

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
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

"""Generate a Python function based on the description."""
def generate_code(description: str) -> str by llm();

with entry {
    desc = "A function that checks if a string is a palindrome";
    code = generate_code(desc);
    print(code);
}
```

---

## Configuration via jac.toml

Instead of setting environment variables, configure in `jac.toml`:

```toml
[plugins.byllm]

[plugins.byllm.model]
default_model = "gpt-4o-mini"
# api_key = "sk-..."  # Or use environment variable

[plugins.byllm.call_params]
temperature = 0.7
max_tokens = 0  # 0 = unlimited
```

---

## Error Handling

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

"""Translate text to Spanish."""
def translate(text: str) -> str by llm();

with entry {
    try {
        result = translate("Hello");
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

"""Translate text."""
def translate(text: str) -> str by llm();

test test_translate {
    result = translate("Hello");
    assert result == "Mocked response 1";
}
```

---

## Key Takeaways

| Concept | Syntax |
|---------|--------|
| Configure LLM | `glob llm = Model(model_name="...")` |
| AI function | `def func() -> Type by llm()` |
| Prompt | Function docstring |
| Type safety | Return type annotation |
| Temperature | `by llm(temperature=0.5)` |
| Max tokens | `by llm(max_tokens=100)` |

---

## Next Steps

- [Structured Outputs](structured-outputs.md) - Return enums, objects, and lists
- [Agentic AI](agentic.md) - Tool calling and ReAct patterns
- [byLLM Reference](../../reference/plugins/byllm.md) - Complete documentation
