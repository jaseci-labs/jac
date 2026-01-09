# AI Integration with byLLM

Jac provides native AI integration through **Meaning-Typed Programming (MTP)** and the `by` syntax, allowing you to seamlessly incorporate LLM capabilities into your applications.

## Core Concept: Meaning-Typed Programming

Instead of writing prompts, you define function signatures with type annotations and docstrings. The LLM infers requirements from these semantic markers:

| Traditional Approach | MTP Approach |
|---------------------|--------------|
| Write verbose prompts | Define typed signatures |
| Parse string responses | Get validated typed returns |
| Manual error handling | Automatic type validation |
| Prompt engineering | Semantic engineering |

---

## Quick Start

```jac
import from byllm.lib { Model }

# Configure the LLM
glob llm = Model(model_name="gpt-4o-mini");

"""Summarize the given text into 2-3 sentences."""
def summarize(text: str) -> str by llm();

with entry {
    summary = summarize("Long article text here...");
    print(summary);
}
```

---

## The `by llm()` Syntax

### Basic Declaration

```jac
def function_name(params) -> ReturnType by llm();
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `temperature` | float | Creativity (0.0-2.0, default 0.7) |
| `max_tokens` | int | Maximum response tokens |
| `stream` | bool | Enable streaming mode |
| `tools` | list | Functions for ReAct pattern |
| `method` | str | "ReAct" for tool-based reasoning |
| `incl_info` | dict | Additional context to include |

### Examples

```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4o-mini");

# Simple LLM call
"""Translate the phrase to Welsh."""
def translate(phrase: str) -> str by llm();

# With temperature control
"""Create a person based on the description."""
def create_person(desc: str) -> Person by llm(temperature=0.0);

# With context injection
"""Analyze data using the provided guidelines."""
def analyze(data: str) -> str by llm(
    incl_info={"guidelines": "Be concise and factual"}
);
```

---

## Supported Providers

byLLM uses LiteLLM, supporting multiple providers:

| Provider | Model Examples |
|----------|---------------|
| OpenAI | gpt-4o, gpt-4o-mini, gpt-4, gpt-3.5-turbo |
| Anthropic | claude-3-sonnet, claude-3-opus, claude-3-haiku |
| Google | gemini/gemini-2.0-flash, gemini-pro |
| Others | Azure, Cohere, Together, Bedrock, etc. |

```jac
# OpenAI
glob llm = Model(model_name="gpt-4o");

# Google
glob llm = Model(model_name="gemini/gemini-2.0-flash");

# Anthropic
glob llm = Model(model_name="claude-3-sonnet-20240229");
```

---

## Custom Return Types

### Enums

```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4o-mini");

enum Sentiment { POSITIVE, NEGATIVE, NEUTRAL }

"""Analyze the sentiment of the text."""
def get_sentiment(text: str) -> Sentiment by llm();

with entry {
    result = get_sentiment("I love this product!");
    print(result);  # Sentiment.POSITIVE
}
```

### Objects (Dataclasses)

```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4o-mini");

obj Person {
    has name: str;
    has age: int;
    has occupation: str;
}

"""Extract person details from the description."""
def extract_person(desc: str) -> Person by llm();

with entry {
    p = extract_person("Alice is a 30-year-old software engineer");
    print(f"{p.name}, {p.age}, {p.occupation}");
}
```

### Lists and Nested Types

```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4o-mini");

obj Item {
    has name: str;
    has price: float;
}

obj Receipt {
    has store: str;
    has items: list[Item];
    has total: float;
}

"""Parse receipt text into structured data."""
def parse_receipt(text: str) -> Receipt by llm();
```

---

## Multimodal Capabilities

### Images

```jac
import from byllm.lib { Model, Image }
glob llm = Model(model_name="gpt-4o");

"""Describe what you see in this image."""
def describe_image(img: Image) -> str by llm();

with entry {
    # From URL
    img = Image(url="https://example.com/photo.jpg");

    # From local file
    img = Image(url="/path/to/image.png");

    description = describe_image(img);
    print(description);
}
```

### Video (Requires byllm[video])

```jac
import from byllm.lib { Model, Video }
glob llm = Model(model_name="gpt-4o");

"""Summarize the key events in this video."""
def analyze_video(v: Video) -> str by llm();

with entry {
    vid = Video(path="video.mp4", fps=1);  # 1 frame/second
    summary = analyze_video(vid);
    print(summary);
}
```

---

## Agentic AI with Tools

### Tool Definition

```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4o-mini");

"""Search Wikipedia for information."""
def search_web(query: str) -> str {
    # Actual implementation
    return f"Results for: {query}";
}

"""Answer questions using available tools."""
def answer_question(question: str) -> str by llm(
    tools=[search_web]
);
```

### ReAct Pattern

The LLM will:

1. Reason about the question
2. Decide which tools to call
3. Use tool results to form the answer
4. Repeat until it has enough information

```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4o");

def calculate(expression: str) -> float {
    return eval(expression);
}

def get_data(topic: str) -> str {
    return f"Data about {topic}";
}

"""Solve complex problems using reasoning and tools."""
def solve(problem: str) -> str by llm(
    method="ReAct",
    tools=[calculate, get_data]
);
```

### Method-Based Tools

```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4o-mini");

obj Calculator {
    def add(x: int, y: int) -> int {
        return x + y;
    }

    def multiply(x: int, y: int) -> int {
        return x * y;
    }

    """Solve math problems using available operations."""
    def solve(problem: str) -> int by llm(
        tools=[self.add, self.multiply]
    );
}

with entry {
    calc = Calculator();
    result = calc.solve("What is 5 plus 3, then multiplied by 2?");
    print(result);  # 16
}
```

---

## Streaming Responses

```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4o-mini");

"""Generate a story about the topic."""
def generate_story(topic: str) -> str by llm(stream=True);

with entry {
    # Result is a generator
    for chunk in generate_story("a brave knight") {
        print(chunk, end="");
    }
}
```

---

## Configuration

### Via jac.toml

```toml
[plugins.byllm]

[plugins.byllm.model]
default_model = "gpt-4o-mini"
api_key = ""  # Or use environment variable

[plugins.byllm.call_params]
temperature = 0.7
max_tokens = 0  # 0 = unlimited
```

### Via Model Constructor

```jac
glob llm = Model(
    model_name="gpt-4o",
    config={
        "api_key": "sk-...",
        "temperature": 0.5
    }
);
```

### Environment Variables

Set provider API keys:

```bash
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
export GOOGLE_API_KEY="..."
```

---

## Semantic Strings (Advanced)

Add semantic hints to improve LLM understanding:

```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4o-mini");

"""A user in the system."""
obj User {
    has name: str;
    has email: str;
    has role: str;
}

# Add semantic hints
sem User.name = "Full legal name of the user";
sem User.email = "Valid email address";
sem User.role = "One of: admin, editor, viewer";

"""Extract user information from the text."""
def extract_user(text: str) -> User by llm();
```

---

## Python Integration

byLLM works in pure Python too:

```python
from byllm.lib import Model, by, Image
from dataclasses import dataclass

@dataclass
class Person:
    name: str
    age: int

llm = Model(model_name="gpt-4o-mini")

@by(llm)
def create_person(description: str) -> Person:
    """Create a person from the description."""
    ...

person = create_person("Bob is 25 years old")
print(person.name, person.age)  # Bob 25
```

---

## Testing with MockLLM

```jac
import from byllm.lib { MockLLM }

glob llm = MockLLM(
    model_name="mockllm",
    config={
        "outputs": ["First response", "Second response"]
    }
);

"""Test function."""
def test_func(input: str) -> str by llm();

with entry {
    print(test_func("test"));  # "First response"
    print(test_func("test"));  # "Second response"
}
```

---

## Learn More

| Topic | Resource |
|-------|----------|
| byLLM Overview | [Introduction](../learn/jac-byllm/with_llm.md) |
| Quickstart | [Getting Started](../learn/jac-byllm/quickstart.md) |
| Usage Guide | [How to Use](../learn/jac-byllm/usage.md) |
| Agentic AI | [Tool Calling & ReAct](../learn/jac-byllm/agentic_ai.md) |
| Multimodal | [Images & Video](../learn/jac-byllm/multimodality.md) |
| Python Mode | [Python Integration](../learn/jac-byllm/python_integration.md) |
| Examples | [Real-world Examples](../learn/jac-byllm/examples.md) |
| The Jac Book | [AI Functions](../jac_book/chapter_4.md) |
