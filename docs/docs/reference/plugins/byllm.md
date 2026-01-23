# byLLM Reference

Complete reference for byLLM, the AI integration framework implementing Meaning-Typed Programming (MTP).

---

## Installation

```bash
pip install byllm
```

---

## Model Configuration

### Basic Setup

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o");
```

### Model Constructor Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `model_name` | str | Yes | Model identifier (e.g., "gpt-4o", "claude-3-5-sonnet-20240620") |
| `api_key` | str | No | API key for the model provider |
| `base_url` | str | No | Custom API endpoint URL |
| `proxy_url` | str | No | Proxy URL (auto-sets base_url) |
| `verbose` | bool | No | Enable debug logging |
| `method` | str | No | Default method ("Reason" for step-by-step) |
| `tools` | list | No | Default tool functions |
| `hyperparams` | dict | No | Model-specific parameters (temperature, max_tokens, etc.) |
| `config` | dict | No | Advanced configuration (http_client, ca_bundle, api_base, etc.) |

### Supported Providers

byLLM uses [LiteLLM](https://docs.litellm.ai/docs/providers) for model integration.

| Provider | Model Name Format | Example |
|----------|-------------------|---------|
| OpenAI | `gpt-*` | `gpt-4o`, `gpt-4o-mini` |
| Anthropic | `claude-*` | `claude-3-5-sonnet-20240620` |
| Google | `gemini/*` | `gemini/gemini-2.0-flash` |
| Ollama | `ollama/*` | `ollama/llama3:70b` |
| HuggingFace | `huggingface/*` | `huggingface/meta-llama/Llama-3.3-70B-Instruct` |

---

## Project Configuration

### System Prompt Override

Override the default system prompt globally via `jac.toml`:

```toml
[plugins.byllm]
system_prompt = "You are a helpful assistant that provides concise answers."
```

The system prompt is automatically applied to all `by llm()` function calls, providing:

- Centralized control over LLM behavior across your project
- Consistent personality without repeating prompts in code
- Easy updates without touching source code

**Example:**

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o");

def greet(name: str) -> str by llm();

with entry {
    # Uses system prompt from jac.toml
    result = greet("Alice");
    print(result);
}
```

### HTTP Client for Custom Endpoints

For custom or self-hosted models, configure HTTP client in the Model constructor:

```jac
import from byllm.lib { Model }

glob llm = Model(
    model_name="custom-model",
    config={
        "api_base": "https://your-endpoint.com/v1/chat/completions",
        "api_key": "your_api_key_here",
        "http_client": True,
        "ca_bundle": True  # True (default SSL), False (skip), or "/path/to/cert.pem"
    }
);
```

**HTTP Client Options:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `api_base` | str | Full URL to your chat completions endpoint |
| `api_key` | str | Bearer token for authentication |
| `http_client` | bool | Enable direct HTTP mode (bypasses LiteLLM) |
| `ca_bundle` | bool/str | SSL certificate verification |

---

## Core Syntax

### Function Declaration

```jac
# Basic function
def function_name(param: type) -> return_type by llm();

# With docstring (recommended)
"""Description of what the function does."""
def function_name(param: type) -> return_type by llm();
```

### Method Declaration

```jac
obj MyClass {
    has attribute: str;

    # Method has access to self attributes
    def method_name() -> str by llm();
}
```

---

## Return Types

### Primitive Types

```jac
def get_summary(text: str) -> str by llm();
def count_words(text: str) -> int by llm();
def is_positive(text: str) -> bool by llm();
def get_score(text: str) -> float by llm();
```

### Enum Types

```jac
enum Sentiment {
    POSITIVE,
    NEGATIVE,
    NEUTRAL
}

def analyze_sentiment(text: str) -> Sentiment by llm();
```

### Object Types

```jac
obj Person {
    has name: str;
    has age: int;
    has bio: str | None;
}

def extract_person(text: str) -> Person by llm();
```

### List Types

```jac
def extract_keywords(text: str) -> list[str] by llm();
def find_people(text: str) -> list[Person] by llm();
```

### Optional Types

```jac
def find_date(text: str) -> str | None by llm();
```

---

## Invocation Parameters

Parameters passed to `by llm()`:

| Parameter | Type | Description |
|-----------|------|-------------|
| `method` | str | "Reason" for step-by-step reasoning |
| `tools` | list | Tool functions for agentic behavior |
| `incl_info` | dict | Additional context key-value pairs |
| `stream` | bool | Enable streaming output (str only) |

### Examples

```jac
# With reasoning
def solve_problem(problem: str) -> str by llm(method="Reason");

# With tools
def calculate(expression: str) -> float by llm(tools=[add, multiply]);

# With additional context
def personalized_greeting(name: str) -> str by llm(
    incl_info={"current_time": get_time(), "location": "NYC"}
);

# With streaming
def generate_story(prompt: str) -> str by llm(stream=True);
```

---

## Semantic Strings (semstrings)

Enrich type semantics for better LLM understanding:

```jac
obj Customer {
    has id: str;
    has name: str;
    has tier: str;
}

# Object-level semantic
sem Customer = "A customer record in the CRM system";

# Attribute-level semantics
sem Customer.id = "Unique customer identifier (UUID format)";
sem Customer.name = "Full legal name of the customer";
sem Customer.tier = "Service tier: 'basic', 'premium', or 'enterprise'";
```

---

## Docstrings

Provide function-level context:

```jac
"""
Translate the given text to the target language.
Preserve formatting and technical terms.
"""
def translate(text: str, target_language: str) -> str by llm();

"""
Analyze customer feedback and categorize the main concerns.
Focus on actionable insights for the product team.
"""
def analyze_feedback(feedback: str) -> list[str] by llm();
```

---

## Tool Calling (ReAct)

### Defining Tools

```jac
"""Get the current date in YYYY-MM-DD format."""
def get_date() -> str {
    import from datetime { datetime }
    return datetime.now().strftime("%Y-%m-%d");
}

"""Search the database for matching records."""
def search_db(query: str, limit: int = 10) -> list[dict] {
    # Implementation
    return results;
}

"""Send an email notification."""
def send_email(to: str, subject: str, body: str) -> bool {
    # Implementation
    return True;
}
```

### Using Tools

```jac
"""Answer questions using available tools."""
def answer_question(question: str) -> str by llm(
    tools=[get_date, search_db, send_email]
);
```

### Method Tools

```jac
obj Calculator {
    has memory: float = 0;

    def add(x: float) -> float {
        self.memory += x;
        return self.memory;
    }

    def clear() -> float {
        self.memory = 0;
        return self.memory;
    }

    """Perform calculations step by step."""
    def calculate(instructions: str) -> str by llm(
        tools=[self.add, self.clear]
    );
}
```

### ReAct Method

For complex multi-step reasoning:

```jac
"""Research and answer complex questions."""
def research(question: str) -> str by llm(
    method="ReAct",
    tools=[search_web, calculate, get_date]
);
```

---

## Streaming

For real-time token output:

```jac
"""Generate a story about the given topic."""
def generate_story(topic: str) -> str by llm(stream=True);

with entry {
    for token in generate_story("space exploration") {
        print(token, end="", flush=True);
    }
    print();
}
```

**Limitations:**

- Only supports `str` return type
- Tool calling not supported in streaming mode

---

## Context Methods

### incl_info

Pass additional context to the LLM:

```jac
obj User {
    has name: str;
    has preferences: dict;

    def get_recommendation() -> str by llm(
        incl_info={
            "current_time": datetime.now().isoformat(),
            "weather": get_weather(),
            "trending": get_trending_topics()
        }
    );
}
```

### Object Context

Methods automatically include object attributes:

```jac
obj Article {
    has title: str;
    has content: str;
    has author: str;

    # LLM sees title, content, and author
    def generate_summary() -> str by llm();
    def suggest_tags() -> list[str] by llm();
}
```

---

## Python Integration

byLLM works in Python with the `@by` decorator:

```python
from byllm.lib import Model, by
from dataclasses import dataclass
from enum import Enum

llm = Model(model_name="gpt-4o")

@by(llm)
def translate(text: str, language: str) -> str:
    """Translate text to the target language."""
    ...

class Sentiment(Enum):
    POSITIVE = "positive"
    NEGATIVE = "negative"
    NEUTRAL = "neutral"

@by(llm)
def analyze(text: str) -> Sentiment:
    """Analyze the sentiment of the text."""
    ...

@dataclass
class Person:
    name: str
    age: int

@by(llm)
def extract_person(text: str) -> Person:
    """Extract person information from text."""
    ...
```

---

## Best Practices

### 1. Clear Docstrings

```jac
# Good
"""Extract all email addresses from the text. Return empty list if none found."""
def extract_emails(text: str) -> list[str] by llm();

# Avoid
def extract_emails(text: str) -> list[str] by llm();
```

### 2. Descriptive Parameters

```jac
# Good
def translate(source_text: str, target_language: str) -> str by llm();

# Avoid
def translate(t: str, l: str) -> str by llm();
```

### 3. Semantic Strings for Complex Types

```jac
obj Order {
    has id: str;
    has status: str;
    has items: list[dict];
}

sem Order.status = "Order status: 'pending', 'processing', 'shipped', 'delivered', 'cancelled'";
sem Order.items = "List of items with 'sku', 'quantity', and 'price' fields";
```

### 4. Tool Docstrings

```jac
"""
Search products in the catalog.

Args:
    query: Search terms
    category: Optional category filter
    max_results: Maximum number of results (default 10)

Returns:
    List of matching product records
"""
def search_products(query: str, category: str = "", max_results: int = 10) -> list[dict] {
    # Implementation
}
```

### 5. Limit Tool Count

Too many tools can confuse the LLM. Keep to 5-10 relevant tools per function.

---

## Error Handling

```jac
with entry {
    try {
        result = my_llm_function(input);
    } except Exception as e {
        print(f"LLM error: {e}");
        # Fallback logic
    }
}
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `OPENAI_API_KEY` | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `GOOGLE_API_KEY` | Google AI API key |
| `HUGGINGFACE_API_KEY` | HuggingFace API key |

---

## Related Resources

- [byLLM Quickstart Tutorial](../../tutorials/ai/quickstart.md)
- [Structured Outputs Tutorial](../../tutorials/ai/structured-outputs.md)
- [Agentic AI Tutorial](../../tutorials/ai/agentic.md)
- [MTP Research Paper](https://arxiv.org/abs/2405.08965)
- [LiteLLM Documentation](https://docs.litellm.ai/docs)
