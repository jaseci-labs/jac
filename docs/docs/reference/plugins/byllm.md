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
| `api_key` | str | No | API key for the model provider (defaults to environment variable) |
| `config` | dict | No | Configuration dictionary (see below) |

**Config Dictionary Options:**

| Key | Type | Description |
|-----|------|-------------|
| `base_url` | str | Custom API endpoint URL (aliases: `host`, `api_base`) |
| `proxy` | bool | Enable proxy mode (uses OpenAI client with base_url) |
| `http_client` | bool | Enable direct HTTP requests (for custom endpoints) |
| `ca_bundle` | str/bool | SSL certificate path, `True` for default, `False` to skip verification |
| `api_key` | str | API key (alternative to constructor parameter) |
| `verbose` | bool | Enable verbose/debug logging |
| `outputs` | list | Mock responses for `MockLLM` testing |

**Example with config:**

```jac
glob llm = Model(
    model_name="gpt-4o",
    config={
        "base_url": "https://your-endpoint.com/v1",
        "proxy": True
    }
);
```

### Supported Providers

byLLM uses [LiteLLM](https://docs.litellm.ai/docs/providers) for model integration, providing access to 100+ providers.

=== "OpenAI"
    ```jac
    import from byllm.lib { Model }

    glob llm = Model(model_name="gpt-4o");
    ```
    ```bash
    export OPENAI_API_KEY="sk-..."
    ```

=== "Anthropic"
    ```jac
    import from byllm.lib { Model }

    glob llm = Model(model_name="claude-3-5-sonnet-20240620");
    ```
    ```bash
    export ANTHROPIC_API_KEY="sk-ant-..."
    ```

=== "Google Gemini"
    ```jac
    import from byllm.lib { Model }

    glob llm = Model(model_name="gemini/gemini-2.0-flash");
    ```
    ```bash
    export GOOGLE_API_KEY="..."
    ```

=== "Ollama (Local)"
    ```jac
    import from byllm.lib { Model }

    glob llm = Model(model_name="ollama/llama3:70b");
    ```
    No API key needed - runs locally. See [Ollama](https://ollama.ai/).

=== "HuggingFace"
    ```jac
    import from byllm.lib { Model }

    glob llm = Model(model_name="huggingface/meta-llama/Llama-3.3-70B-Instruct");
    ```
    ```bash
    export HUGGINGFACE_API_KEY="hf_..."
    ```

**Provider Model Name Formats:**

| Provider | Model Name Format | Example |
|----------|-------------------|---------|
| OpenAI | `gpt-*` | `gpt-4o`, `gpt-4o-mini` |
| Anthropic | `claude-*` | `claude-3-5-sonnet-20240620` |
| Google | `gemini/*` | `gemini/gemini-2.0-flash` |
| Ollama | `ollama/*` | `ollama/llama3:70b` |
| HuggingFace | `huggingface/*` | `huggingface/meta-llama/Llama-3.3-70B-Instruct` |

??? tip "Full Provider List"
    For the complete list of supported providers and model name formats, see the [LiteLLM providers documentation](https://docs.litellm.ai/docs/providers).

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

# With sem for additional context (recommended for ambiguous names)
def function_name(param: type) -> return_type by llm();
sem function_name = "Description of what the function does.";
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

Parameters passed to `by llm()` at call time:

| Parameter | Type | Description |
|-----------|------|-------------|
| `temperature` | float | Controls randomness (0.0 = deterministic, 2.0 = creative). Default: 0.7 |
| `max_tokens` | int | Maximum tokens in response |
| `tools` | list | Tool functions for agentic behavior (enables ReAct loop) |
| `incl_info` | dict | Additional context key-value pairs injected into the prompt |
| `stream` | bool | Enable streaming output (only supports `str` return type) |
| `max_react_iterations` | int | Maximum ReAct iterations before forcing final answer |

### Examples

```jac
# With temperature control
def generate_story(prompt: str) -> str by llm(temperature=1.5);
def extract_facts(text: str) -> str by llm(temperature=0.0);

# With max tokens
def summarize(text: str) -> str by llm(max_tokens=100);

# With tools (enables ReAct loop)
def calculate(expression: str) -> float by llm(tools=[add, multiply]);

# With additional context
def personalized_greeting(name: str) -> str by llm(
    incl_info={"current_time": get_time(), "location": "NYC"}
);

# With streaming
def generate_essay(topic: str) -> str by llm(stream=True);
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

    def calculate(instructions: str) -> str by llm(
        tools=[self.add, self.clear]
    );
}
```

---

## Streaming

For real-time token output:

```jac
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
def translate(text: str, language: str) -> str:  ...

class Sentiment(Enum):
    POSITIVE = "positive"
    NEGATIVE = "negative"
    NEUTRAL = "neutral"

@by(llm)
def analyze(text: str) -> Sentiment: ...

@dataclass
class Person:
    name: str
    age: int

@by(llm)
def extract_person(text: str) -> Person: ...
```

---

## Best Practices

### 1. Descriptive Names and `sem` for Clarity

```jac
# Good - name is self-explanatory
def extract_emails(text: str) -> list[str] by llm();

# Better - sem adds detail when needed
def extract_emails(text: str) -> list[str] by llm();
sem extract_emails = "Extract all email addresses from the text. Return empty list if none found.";
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

### 4. Tool Semantics

Use `sem` to describe tools so the LLM knows when to call them:

```jac
sem search_products = "Search products in the catalog and return matching records.";
sem search_products.query = "Search terms";
sem search_products.category = "Optional category filter";
sem search_products.max_results = "Maximum number of results (default 10)";
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

## LiteLLM Proxy Server

byLLM can connect to a [LiteLLM proxy server](https://docs.litellm.ai/docs/simple_proxy) for enterprise deployments. This allows centralized model management, rate limiting, and cost tracking.

### Setup

1. Deploy LiteLLM proxy following the [official documentation](https://docs.litellm.ai/docs/proxy/deploy)

2. Connect byLLM to the proxy:

```jac
import from byllm.lib { Model }

glob llm = Model(
    model_name="gpt-4o",
    api_key="your_litellm_virtual_key",
    proxy_url="http://localhost:8000"
);
```

```python
from byllm.lib import Model

llm = Model(
    model_name="gpt-4o",
    api_key="your_litellm_virtual_key",
    proxy_url="http://localhost:8000"
)
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `model_name` | The model to use (must be configured in LiteLLM proxy) |
| `api_key` | LiteLLM virtual key or master key (not the provider API key) |
| `proxy_url` | URL of your LiteLLM proxy server |

For virtual key generation, see [LiteLLM Virtual Keys](https://docs.litellm.ai/docs/proxy/virtual_keys).

---

## Creating Custom Model Classes

For self-hosted models or custom APIs not supported by LiteLLM, create a custom model class by inheriting from `BaseLLM`.

### Implementation

=== "Python"
    ```python
    from byllm.llm import BaseLLM
    from openai import OpenAI

    class MyCustomModel(BaseLLM):
        def __init__(self, model_name: str, **kwargs) -> None:
            """Initialize the custom model."""
            super().__init__(model_name, **kwargs)

        def model_call_no_stream(self, params):
            """Handle non-streaming calls."""
            client = OpenAI(api_key=self.api_key)
            response = client.chat.completions.create(**params)
            return response

        def model_call_with_stream(self, params):
            """Handle streaming calls."""
            client = OpenAI(api_key=self.api_key)
            response = client.chat.completions.create(stream=True, **params)
            return response
    ```

=== "Jac"
    ```jac
    import from byllm.llm { BaseLLM }
    import from openai { OpenAI }

    obj MyCustomModel(BaseLLM) {
        has model_name: str;
        has config: dict = {};

        def post_init() {
            super().__init__(model_name=self.model_name, **self.config);
        }

        def model_call_no_stream(params: dict) {
            client = OpenAI(api_key=self.api_key);
            response = client.chat.completions.create(**params);
            return response;
        }

        def model_call_with_stream(params: dict) {
            client = OpenAI(api_key=self.api_key);
            response = client.chat.completions.create(stream=True, **params);
            return response;
        }
    }
    ```

### Usage

```jac
glob llm = MyCustomModel(model_name="my-custom-model");

def generate(prompt: str) -> str by llm();
```

### Required Methods

| Method | Description |
|--------|-------------|
| `model_call_no_stream(params)` | Handle standard (non-streaming) LLM calls |
| `model_call_with_stream(params)` | Handle streaming LLM calls |

The `params` dictionary contains the formatted request including messages, model name, and any additional parameters.

---

## Advanced Python Integration

byLLM provides two modes for Python integration:

### Mode 1: Direct Python Import

Import byLLM directly in Python using the `@by` decorator:

```python
import jaclang
from dataclasses import dataclass
from byllm.lib import Model, Image, by

llm = Model(model_name="gpt-4o")

@dataclass
class Person:
    full_name: str
    description: str
    year_of_birth: int

@by(llm)
def get_person_info(img: Image) -> Person: ...

# Usage
img = Image("photo.jpg")
person = get_person_info(img)
print(f"Name: {person.full_name}")
```

### Mode 2: Implement in Jac, Import to Python (Recommended)

Implement AI features in Jac and import seamlessly into Python:

=== "ai.jac"
    ```jac
    import from byllm.lib { Model, Image }

    glob llm = Model(model_name="gpt-4o");

    obj Person {
        has full_name: str;
        has description: str;
        has year_of_birth: int;
    }

    sem Person.description = "Short biography";

    def get_person_info(img: Image) -> Person by llm();
    sem get_person_info = "Extract person information from the image.";
    ```

=== "main.py"
    ```python
    import jaclang
    from ai import Image, Person, get_person_info

    img = Image("photo.jpg")
    person = get_person_info(img)
    print(f"Name: {person.full_name}")
    ```

### Semstrings in Python

Use the `@Jac.sem` decorator for semantic strings in Python:

```python
from jaclang import JacRuntimeInterface as Jac
from dataclasses import dataclass
from byllm.lib import Model, by

llm = Model(model_name="gpt-4o")

@Jac.sem("Represents a personal record", {
    "name": "Full legal name",
    "dob": "Date of birth (YYYY-MM-DD)",
    "ssn": "Last four digits of Social Security Number"
})
@dataclass
class Person:
    name: str
    dob: str
    ssn: str

@by(llm)
def check_eligibility(person: Person, service: str) -> bool: ...
```

### Hyperparameters in Python

```python
@by(llm(temperature=0.3, max_tokens=100))
def generate_joke() -> str: ...
```

### Tools in Python

```python
def get_weather(city: str) -> str:
    return f"The weather in {city} is sunny."

@by(llm(tools=[get_weather]))
def answer_question(question: str) -> str: ...
```

---

## Related Resources

- [byLLM Quickstart Tutorial](../../tutorials/ai/quickstart.md)
- [Structured Outputs Tutorial](../../tutorials/ai/structured-outputs.md)
- [Agentic AI Tutorial](../../tutorials/ai/agentic.md)
- [Multimodal AI Tutorial](../../tutorials/ai/multimodal.md)
- [Creating byLLM Plugins](creating-plugins.md)
- [MTP Research Paper](https://arxiv.org/abs/2405.08965)
- [LiteLLM Documentation](https://docs.litellm.ai/docs)
