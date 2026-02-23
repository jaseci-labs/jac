# byLLM Reference

Complete reference for byLLM, the AI integration framework implementing Meaning-Typed Programming (MTP).

---

## Meaning Typed Programming

Meaning Typed Programming (MTP) is Jac's core AI paradigm. Your function signature -- the name, parameter names, and types -- becomes the specification. The LLM reads this "meaning" and generates appropriate behavior. This works because well-named functions already describe their intent; MTP just makes that intent executable.

### The Concept

MTP treats semantic intent as a first-class type. You declare *what* you want, and AI provides *how*:

```jac
# The function signature IS the specification
def classify_sentiment(text: str) -> str by llm;

# Usage - the LLM infers behavior from the name and types
with entry {
    result = classify_sentiment("I love this product!");
    # result = "positive"
}
```

### Implicit vs Explicit Semantics

**Implicit** -- derived from function/parameter names:

```jac
def translate_to_spanish(text: str) -> str by llm;
```

**Explicit** -- using `sem` for detailed descriptions:

```jac
sem classify = """
Analyze the emotional tone of the input text.
Return exactly one of: 'positive', 'negative', 'neutral'.
Consider context and sarcasm.
""";

def classify(text: str) -> str by llm;
```

### Type Validation

byLLM validates that LLM responses match the declared return type. If the LLM returns an invalid type, byLLM will:

1. **Attempt coercion** -- e.g., string `"5"` becomes integer `5`
2. **Raise an error** if coercion fails

This means your Jac type system functions as the LLM's output schema. Declaring `-> int` guarantees you receive an integer, and declaring `-> MyObj` guarantees you receive a properly structured object.

---

## Installation

```bash
pip install byllm
```

For video support, install with the `video` extra:

```bash
pip install byllm[video]
```

---

## Model Configuration

### Default (Zero-Config)

`llm` is a **built-in name** in Jac -- just use `by llm()` directly with no imports:

```jac
def summarize(text: str) -> str by llm();

with entry {
    print(summarize("Jac is a programming language..."));
}
```

The default model is `gpt-4o-mini`. Configure it via `jac.toml` (see [Default Model Configuration](#default-model-configuration) below).

### Custom Model (Override)

For per-file customization, override the builtin with an explicit `Model`:

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
    ```toml
    [plugins.byllm.model]
    default_model = "gpt-4o"
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

=== "Google Gemini"
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
    No API key needed - runs locally. See [Ollama](https://ollama.ai/).

=== "HuggingFace"
    ```toml
    [plugins.byllm.model]
    default_model = "huggingface/meta-llama/Llama-3.3-70B-Instruct"
    ```
    ```bash
    export HUGGINGFACE_API_KEY="hf_..."
    ```

You can also override per-file with `glob llm = Model(...)` (see [Custom Model (Override)](#custom-model-override)).

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

### Default Model Configuration

The builtin `llm` is configured via `jac.toml`. This controls the model used by any `by llm()` call that doesn't explicitly override `llm`:

```toml
[plugins.byllm.model]
default_model = "gpt-4o-mini"    # Model to use (any LiteLLM-supported model)
api_key = ""                      # API key (env vars take precedence)
base_url = ""                     # Custom API endpoint URL
proxy = false                     # Enable proxy mode (uses OpenAI client)
verbose = false                   # Log LLM calls to stderr

[plugins.byllm.call_params]
temperature = 0.7                 # Model creativity (0.0-2.0)
max_tokens = 0                    # Max response tokens (0 = no limit)

[plugins.byllm.litellm]
local_cost_map = true             # Use local cost map
drop_params = true                # Drop unsupported params per provider
```

**`[plugins.byllm.model]` options:**

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `default_model` | str | `"gpt-4o-mini"` | LiteLLM model identifier (e.g. `"gpt-4o"`, `"claude-sonnet-4-6"`, `"gemini/gemini-2.0-flash"`) |
| `api_key` | str | `""` | API key for the provider. Environment variables (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, etc.) take precedence |
| `base_url` | str | `""` | Custom API endpoint URL (for proxy or self-hosted models) |
| `proxy` | bool | `false` | Enable proxy mode (uses OpenAI client instead of LiteLLM) |
| `verbose` | bool | `false` | Log LLM calls and parameters to stderr |

**`[plugins.byllm.call_params]` options:**

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `temperature` | float | `0.7` | Creativity/randomness (0.0-2.0, lower is more deterministic) |
| `max_tokens` | int | `0` | Maximum response tokens (0 = no limit / model default) |

**`[plugins.byllm.litellm]` options:**

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `local_cost_map` | bool | `true` | Use local cost map instead of fetching from remote |
| `drop_params` | bool | `true` | Silently drop parameters unsupported by the chosen provider |

**Minimal setup** -- just set your API key and go:

```bash
export OPENAI_API_KEY="sk-..."
```

```jac
# No imports needed -- llm is a builtin
def greet(name: str) -> str by llm();

with entry {
    print(greet("Alice"));
}
```

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

### Inline Expression

The `by llm` operator can also be used as an inline expression without a function declaration:

```jac
with entry {
    response = "Explain quantum computing in simple terms" by llm;
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

### Chained Transformations

Compose multiple LLM calls using the pipe operator:

```jac
with entry {
    text = "Some input text";
    result = text
        |> (lambda t: str -> str: t by llm("Correct grammar"))
        |> (lambda t: str -> str: t by llm("Simplify language"))
        |> (lambda t: str -> str: t by llm("Translate to Spanish"));
}
```

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

The `sem` keyword attaches semantic descriptions to functions, parameters, type fields, and enum values. These strings are included in the compiler-generated prompt so the LLM sees them at runtime.

!!! tip "Best practice"
    Always use `sem` to provide context for `by llm()` functions and parameters. Docstrings are for human documentation (and auto-generated API docs) but are **not** included in compiler-generated prompts. Only `sem` declarations affect LLM behavior.

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

# Enum value semantics
enum Priority { LOW, MEDIUM, HIGH }
sem Priority.HIGH = "Urgent: requires immediate attention";
```

### Parameter Semantics

```jac
sem analyze_code.code = "The source code to analyze";
sem analyze_code.language = "Programming language (python, javascript, etc.)";
sem analyze_code.return = "A structured analysis with issues and suggestions";

def analyze_code(code: str, language: str) -> dict by llm;
```

### Complex Semantic Types

```jac
obj CodeAnalysis {
    has issues: list[str];
    has suggestions: list[str];
    has complexity_score: int;
    has summary: str;
}

sem analyze.return = """
Return a CodeAnalysis object with:
- issues: List of problems found
- suggestions: Improvement recommendations
- complexity_score: 1-10 complexity rating
- summary: One paragraph overview
""";

def analyze(code: str) -> CodeAnalysis by llm;
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

## Multimodal Inputs

byLLM supports image and video inputs through the `Image` and `Video` types. These can be used as parameters in any `by llm()` function or method.

### Image Type

Import and use the `Image` type for image inputs:

```jac
import from byllm.lib { Image }

"""Describe what you see in this image."""
def describe_image(img: Image) -> str by llm();

with entry {
    image = Image("photo.jpg");
    description = describe_image(image);
    print(description);
}
```

#### Supported Input Formats

The `Image` constructor accepts multiple formats:

| Format | Example |
|--------|---------|
| File path | `Image("photo.jpg")` |
| URL (http/https) | `Image("https://example.com/image.png")` |
| Google Cloud Storage | `Image("gs://bucket/path/image.png")` |
| Data URL | `Image("data:image/png;base64,...")` |
| PIL Image | `Image(pil_image)` |
| Bytes | `Image(raw_bytes)` |
| BytesIO | `Image(bytes_io_buffer)` |
| pathlib.Path | `Image(Path("photo.jpg"))` |

#### In-Memory Usage

```jac
import from byllm.lib { Image }
import io;
import from PIL { Image as PILImage }

with entry {
    pil_img = PILImage.open("photo.jpg");

    # From BytesIO buffer
    buf = io.BytesIO();
    pil_img.save(buf, format="PNG");
    img_from_buffer = Image(buf);

    # From raw bytes
    img_from_bytes = Image(buf.getvalue());

    # From PIL image directly
    img_from_pil = Image(pil_img);
}
```

### Structured Output from Images

Image inputs combine with all return types -- primitives, enums, objects, and lists:

```jac
import from byllm.lib { Image }

obj LineItem {
    has description: str;
    has quantity: int;
    has price: float;
}

obj Receipt {
    has store_name: str;
    has date: str;
    has items: list[LineItem];
    has total: float;
}

"""Extract all information from this receipt image."""
def parse_receipt(img: Image) -> Receipt by llm();

with entry {
    receipt = parse_receipt(Image("receipt.jpg"));
    print(f"Store: {receipt.store_name}");
    for item in receipt.items {
        print(f"  - {item.description}: ${item.price}");
    }
    print(f"Total: ${receipt.total}");
}
```

### Video Type

The `Video` type processes videos by extracting frames at a configurable rate:

```jac
import from byllm.lib { Video }

"""Describe what happens in this video."""
def explain_video(video: Video) -> str by llm();

with entry {
    video = Video(path="sample_video.mp4", fps=1);
    explanation = explain_video(video);
    print(explanation);
}
```

!!! note "Video requires extra dependency"
    Video support requires `pip install byllm[video]`.

#### Video Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | str | required | Path to the video file |
| `fps` | int | 1 | Frames per second to extract |

Lower `fps` values extract fewer frames, reducing token usage. Higher values provide more temporal detail.

#### Structured Output from Videos

```jac
import from byllm.lib { Video }

obj VideoAnalysis {
    has summary: str;
    has key_events: list[str];
    has duration_estimate: str;
    has content_type: str;
}

"""Analyze this video and extract key information."""
def analyze_video(video: Video) -> VideoAnalysis by llm();
```

### Multimodal with Tools

Image and video inputs work with tool calling:

```jac
import from byllm.lib { Image }

"""Search for products matching the description."""
def search_products(query: str) -> list[str] {
    return [f"Product matching '{query}' - $29.99"];
}

"""Look at the image and find similar products."""
def find_similar_products(img: Image) -> str by llm(
    tools=[search_products]
);

with entry {
    results = find_similar_products(Image("shoe.jpg"));
    print(results);
}
```

### Python Multimodal Integration

Multimodal works in both Python integration modes:

```python
import jaclang
from byllm.lib import Model, Image, by

llm = Model(model_name="gpt-4o")

@by(llm)
def describe(img: Image) -> str: ...

img = Image("photo.jpg")
print(describe(img))
```

For a step-by-step walkthrough, see the [Multimodal AI Tutorial](../../tutorials/ai/multimodal.md).

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

## Testing with MockLLM

Use `MockLLM` for deterministic testing without API calls. Mock responses are returned sequentially from the `outputs` list:

```jac
import from byllm.lib { MockLLM }

glob llm = MockLLM(
    model_name="mockllm",
    config={
        "outputs": ["Mocked response 1", "Mocked response 2"]
    }
);

def translate(text: str) -> str by llm();
def summarize(text: str) -> str by llm();

test "translate returns first mock" {
    result = translate("Hello");
    assert result == "Mocked response 1";
}

test "summarize returns second mock" {
    result = summarize("Long text...");
    assert result == "Mocked response 2";
}
```

`MockLLM` is useful for:

- Unit testing LLM-powered functions without API costs
- Deterministic assertions on function behavior
- CI/CD pipelines where API keys aren't available

---

## Complex Structured Output Example

byLLM validates that responses match the declared return type, coercing when possible (e.g., `"5"` → `5`) and raising errors when coercion fails. This enables deeply nested structured outputs:

??? example "Resume Parser"

    ```jac
    import from typing { Optional }

    obj Education {
        has degree: str;
        has institution: str;
        has year: int;
    }

    obj Experience {
        has title: str;
        has company: str;
        has years: int;
        has description: str;
    }

    obj Resume {
        has name: str;
        has email: str;
        has phone: Optional[str];
        has skills: list[str];
        has education: list[Education];
        has experience: list[Experience];
    }

    def parse_resume(text: str) -> Resume by llm();

    with entry {
        resume_text = """
        John Smith
        john.smith@email.com | (555) 123-4567

        SKILLS: Python, JavaScript, Machine Learning, AWS

        EDUCATION
        BS Computer Science, MIT, 2018
        MS Data Science, Stanford, 2020

        EXPERIENCE
        Senior Engineer at Google (3 years) - Led recommendation systems team
        Software Developer at Startup Inc (2 years) - Full-stack web development
        """;

        resume = parse_resume(resume_text);
        print(f"Name: {resume.name}");
        print(f"Skills: {', '.join(resume.skills)}");
        for edu in resume.education {
            print(f"  - {edu.degree} from {edu.institution} ({edu.year})");
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
    import from byllm.lib { Image }

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

## Agentic AI Patterns

### AI Agents as Walkers

Combine graph traversal with LLM reasoning by using walkers as AI agents:

```jac
walker AIAgent {
    has goal: str;
    has memory: list = [];

    can decide with Node entry {
        context = f"Goal: {self.goal}\nCurrent: {here}\nMemory: {self.memory}";
        decision = context by llm("Decide next action");
        self.memory.append({"location": here, "decision": decision});
        visit [-->];
    }
}
```

### Tool-Using Agents

Agents combine LLM reasoning with tool functions. The LLM decides which tools to call and in what order (ReAct loop):

```jac
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o");

glob kb: dict = {
    "products": ["Widget A", "Widget B", "Service X"],
    "prices": {"Widget A": 99, "Widget B": 149, "Service X": 29},
    "inventory": {"Widget A": 50, "Widget B": 0, "Service X": 999}
};

"""List all available products."""
def list_products() -> list[str] {
    return kb["products"];
}

"""Get the price of a product."""
def get_price(product: str) -> str {
    if product in kb["prices"] {
        return f"${kb['prices'][product]}";
    }
    return "Product not found";
}

"""Check if a product is in stock."""
def check_inventory(product: str) -> str {
    qty = kb["inventory"].get(product, 0);
    return f"In stock ({qty} available)" if qty > 0 else "Out of stock";
}

def sales_agent(request: str) -> str by llm(
    tools=[list_products, get_price, check_inventory]
);
sem sales_agent = "Help customers browse products, check prices and availability.";
```

### Context Injection with `incl_info`

Pass additional runtime context to the LLM without modifying function signatures:

```jac
glob company_info = """
Company: TechCorp
Products: CloudDB, SecureAuth, DataViz
Support Hours: 9 AM - 5 PM EST
""";

def support_agent(question: str) -> str by llm(
    incl_info={"company_context": company_info}
);
sem support_agent = "Answer customer questions about our products and services.";
```

The `incl_info` dict keys and values are injected into the prompt as additional context. This is useful for dynamic information that changes between calls.

### Agentic Walkers

Walkers that traverse document graphs and use LLM for analysis:

```jac
node Document {
    has title: str;
    has content: str;
    has summary: str = "";
}

def summarize(content: str) -> str by llm();
sem summarize = "Summarize this document in 2-3 sentences.";

walker DocumentAgent {
    has query: str;

    can process with Root entry {
        all_docs = [-->](?:Document);

        for doc in all_docs {
            if self.query.lower() in doc.content.lower() {
                doc.summary = summarize(doc.content);
                report {"title": doc.title, "summary": doc.summary};
            }
        }
    }
}
```

### Multi-Agent Systems

Orchestrate multiple specialized walkers:

```jac
walker Coordinator {
    can coordinate with Root entry {
        research = root spawn Researcher(topic="AI");
        writer = root spawn Writer(style="technical");
        reviewer = root spawn Reviewer();

        report {
            "research": research.reports,
            "draft": writer.reports,
            "review": reviewer.reports
        };
    }
}
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
