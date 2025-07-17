# Quick Start Guide

## Installation

To get started with MTLLM, install the base package:

```bash
pip install mtllm
```

MTLLM supports multiple LLM providers. Choose and install the integration you need:

=== "OpenAI"
    ```bash
    pip install mtllm[openai]
    ```
=== "Anthropic"
    ```bash
    pip install mtllm[anthropic]
    ```
=== "Google"
    ```bash
    pip install mtllm[google]
    ```
=== "Groq"
    ```bash
    pip install mtllm[groq]
    ```
=== "Huggingface"
    ```bash
    pip install mtllm[huggingface]
    ```
=== "Ollama"
    ```bash
    pip install mtllm[ollama]
    ```
=== "Together"
    ```bash
    pip install mtllm[together]
    ```

## Your First AI Integrated Function

Let's build a simple translation function that demonstrates how MTLLM transforms ordinary functions into intelligent, reasoning components.

### The Traditional Approach

Here's how you'd typically handle translation with manual API integration:

```jac
def translate(eng_sentence: str, target_lang: str) -> str {
    # Traditional approach: manual API calls, prompt engineering, response parsing
    # Lots of boilerplate code would go here...

    return "Hola Mundo";  # Hardcoded for demo
}

with entry {
    print(translate("Hello World", "es"));
}
```

**The Problem**: You're limited to language codes (`es`, `fr`, etc.) and need extensive prompt engineering to handle natural language inputs like "Language spoken in Somalia" or "The language of Shakespeare."

### The MTP Way: `by` keyword

With the `by` keyword abstraction in MTLLM, your functions become intelligent agents that can reason about their inputs and produce contextually appropriate outputs:

#### Step 1: Import Your LLM

```jac
import from mtllm.llm {Model}

glob llm = Model(model_name="gpt-4o");
```

#### Step 2: Transform Your Function into an Agent

Simply add `by llm` to make your function AI-integrated:

```jac
import from mtllm.llm {Model}

glob llm = Model(model_name="gpt-4o");

def translate(eng_sentence: str, target_lang: str) -> str by llm();

with entry {
    print(translate("Hello World", "Language spoken in Somalia"));
    print(translate("Good morning", "The language of Cervantes"));
    print(translate("Thank you", "What people speak in Tokyo"));
}
```

**That's it!** 🎉 Your function now intelligently understands natural language descriptions and performs contextual translation.

#### Step 3: Run Your AI Integrated Application

Set your API key and run:

```bash
export OPENAI_API_KEY="your-api-key-here"
jac run translator.jac
```

Ready to explore more advanced ways of using the `by` abstraction? Continue with the [Usage Guide](./usage.md) to learn about all the ways you can build AI-integrated software with MTLLM, including object methods, function overriding, and complex multi-agent workflows.
