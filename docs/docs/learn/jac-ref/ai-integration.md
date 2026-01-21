# Part V: AI Integration

Jac's AI integration goes beyond simple API calls. With "Meaning Typed Programming," you write function signatures that describe *what* you want, and the LLM figures out *how* to do it. This inverts the traditional programming model: instead of writing algorithms, you declare intent and let AI provide the implementation. The `by llm` operator makes this seamless.

> **Prerequisites:**
>
> - [The `by` Operator](foundation.md#69-the-by-operator) - Basic syntax
> - [Function Declaration](functions-objects.md#81-function-declaration) - Function signatures
>
> **Required Plugin:** `pip install byllm`

## 26. Meaning Typed Programming

Meaning Typed Programming (MTP) is Jac's core AI paradigm. Your function signature -- the name, parameter names, and types -- becomes the specification. The LLM reads this "meaning" and generates appropriate behavior. This works because well-named functions already describe their intent; MTP just makes that intent executable.

### 26.1 The Concept

Meaning Typed Programming treats semantic intent as a first-class type. You declare *what* you want, and AI provides *how*:

```jac
# The function signature IS the specification
def classify_sentiment(text: str) -> str by llm;

# Usage - the LLM infers behavior from the name and types
result = classify_sentiment("I love this product!");
# result = "positive"
```

### 26.2 Implicit vs Explicit Semantics

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

---

## 27. Semantic Strings

When function names alone don't provide enough context, use `sem` (semantic) declarations to add detailed descriptions. The LLM reads these descriptions as part of its prompt, giving you precise control over behavior. Think of `sem` as documentation that actually affects execution.

### 27.1 The `sem` Keyword

```jac
sem classify_sentiment = """
Analyze the emotional tone of the text.
Return 'positive', 'negative', or 'neutral'.
Consider nuance, sarcasm, and context.
""";

def classify_sentiment(text: str) -> str by llm;
```

### 27.2 Parameter Semantics

```jac
sem analyze_code.code = "The source code to analyze";
sem analyze_code.language = "Programming language (python, javascript, etc.)";
sem analyze_code.return = "A structured analysis with issues and suggestions";

def analyze_code(code: str, language: str) -> dict by llm;
```

### 27.3 Complex Semantic Types

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

## 28. The `by` Operator and LLM Delegation

### 28.1 Basic Usage

```jac
# Inline expression
response = "Explain quantum computing in simple terms" by llm;

# Function delegation
def translate(text: str, target_lang: str) -> str by llm;

def summarize(article: str) -> str by llm;

def extract_entities(text: str) -> list[str] by llm;
```

### 28.2 Chained Transformations

```jac
result = text
    |> (lambda t: str -> str: t by llm("Correct grammar"))
    |> (lambda t: str -> str: t by llm("Simplify language"))
    |> (lambda t: str -> str: t by llm("Translate to Spanish"));
```

### 28.3 Model Configuration

```jac
def summarize(text: str) -> str by llm(
    model_name="gpt-4",
    temperature=0.7,
    max_tokens=2000
);

def creative_story(prompt: str) -> str by llm(
    model_name="claude-3-opus",
    temperature=1.0
);
```

**Configuration Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `model_name` | str | LLM provider/model identifier |
| `temperature` | float | Creativity (0.0-2.0) |
| `max_tokens` | int | Maximum response tokens |
| `stream` | bool | Enable streaming output |
| `tools` | list | Functions for tool calling |
| `method` | str | ReAct, Reason, Chain-of-Thoughts |
| `context` | list[str] | Additional system instructions |

### 28.4 Tool Calling (ReAct)

```jac
def get_weather(city: str) -> str {
    # Actual implementation
    return fetch_weather_api(city);
}

def search_web(query: str) -> list[str] {
    # Actual implementation
    return web_search_api(query);
}

def answer_question(question: str) -> str by llm(
    tools=[get_weather, search_web],
    method="ReAct"
);

# The LLM can now call these tools to answer questions
result = answer_question("What's the weather in Paris?");
```

### 28.5 Streaming Responses

```jac
def stream_story(prompt: str) -> str by llm(stream=True);

# Returns generator
for chunk in stream_story("Tell me a story") {
    print(chunk, end="");
}
```

### 28.6 Multimodal Input

```jac
import from byllm { Image, Video }

def describe_image(image: Image) -> str by llm;
def analyze_video(video: Video) -> str by llm;

# Usage
description = describe_image(Image("photo.jpg"));
description = describe_image(Image("https://example.com/image.png"));
```

### 28.7 Reasoning Methods

| Method | Description |
|--------|-------------|
| `Chain-of-Thoughts` | Step-by-step reasoning before answer |
| `Reason` | Explicit reasoning output |
| `ReAct` | Reasoning + Acting with tools |

```jac
def solve_math(problem: str) -> str by llm(method="Chain-of-Thoughts");
def complex_task(query: str) -> str by llm(method="ReAct", tools=[...]);
```

### 28.8 Testing with MockLLM

```jac
def classify(text: str) -> str by llm(
    model_name="mockllm",
    config={"outputs": ["positive", "negative", "neutral"]}
);

test classification_test {
    result = classify("Great product!");
    assert result in ["positive", "negative", "neutral"];
}
```

### 28.9 Configuration via jac.toml

```toml
[plugins.byllm.model]
default = "gpt-4"

[plugins.byllm.call_params]
temperature = 0.7
max_tokens = 1000

[plugins.byllm.litellm]
api_base = "http://localhost:4000"
```

### 28.10 Python Library Mode

Use `by` in pure Python with decorators:

```python
from byllm import by, Model

@by(Model("gpt-4"))
def summarize(text: str) -> str:
    """Summarize the given text."""
    pass

result = summarize("Long article text...")
```

---

## 29. Agentic AI Patterns

### 29.1 AI Agents as Walkers

```jac
walker AIAgent {
    has goal: str;
    has memory: list = [];

    can decide with Node entry {
        context = f"Goal: {self.goal}\nCurrent: {here}\nMemory: {self.memory}";
        decision = context by llm("Decide next action");
        self.memory.append({"location": here, "decision": decision});
        # Act on decision
        visit [-->];
    }
}
```

### 29.2 Tool-Using Agents

```jac
walker ResearchAgent {
    has query: str;

    def search(query: str) -> list[str] {
        return web_search(query);
    }

    def read_page(url: str) -> str {
        return fetch_content(url);
    }

    can research with `root entry by llm(
        tools=[self.search, self.read_page],
        method="ReAct"
    );
}
```

### 29.3 Multi-Agent Systems

```jac
walker Coordinator {
    can coordinate with `root entry {
        # Spawn specialized agents
        research = root spawn Researcher(topic="AI");
        writer = root spawn Writer(style="technical");
        reviewer = root spawn Reviewer();

        # Combine results
        report {
            "research": research.reports,
            "draft": writer.reports,
            "review": reviewer.reports
        };
    }
}
```

---
