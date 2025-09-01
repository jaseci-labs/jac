# byLLM - AI Integration Framework for Jac-lang

[![PyPI version](https://img.shields.io/pypi/v/mtllm.svg)](https://pypi.org/project/mtllm/) [![tests](https://github.com/jaseci-labs/jaseci/actions/workflows/test-jaseci.yml/badge.svg?branch=main)](https://github.com/jaseci-labs/jaseci/actions/workflows/test-jaseci.yml)

Meaning Typed Programming (MTP) is a programming paradigm for AI integration where prompt engineering is hidden through code semantics. byLLM is the plugin built, exploring this hypothesis. byLLM is built as a plugin to the Jaseci ecosystem. This plugin can be installed as a PyPI package.

```bash
pip install byllm
```

## Basic Example

A basic usecase of MTP can be demonstrated as follows:

```python
import from byllm {Model}

glob llm = Model(model_name="openai\gpt-4o");

def translate_to(language: str, phrase: str) -> str by llm();

with entry {
    output = translate_to(language="Welsh", phrase="Hello world");
    print(output);
}
```

## AI-Powered Object Generation

```python
import from byllm {Model}

glob llm = Model(model_name="gpt-4o");

obj Task {
    has description: str,
        priority: int,
        estimated_time: int;
}

sem Task.priority = "priority between 0 (highest priority) and 10(lowest priority)";

def create_task(description: str, previous_tasks: list[Task]) -> Task by llm();

with entry {
    tasks = [];
    new_task = create_task("Write documentation for the API", tasks);
    print(f"Task: {new_task.description}, Priority: {new_task.priority}, Time: {new_task.estimated_time}min");
}
```

The `by` abstraction allows to automate semantic extraction from existing code semantics, eliminating manual prompt engineering while leveraging type annotations for structured AI responses.

## Documentation and Examples

**📚 Full Documentation**: [Jac byLLM Documentation](https://www.jac-lang.org/learn/jac-byllm/with_llm/)

**🎮 Complete Examples**:
- [Fantasy Trading Game](https://www.jac-lang.org/learn/examples/mtp_examples/fantasy_trading_game/) - Interactive RPG with AI-generated characters
- [RPG Level Generator](https://www.jac-lang.org/learn/examples/mtp_examples/rpg_game/) - AI-powered game level creation
- [RAG Chatbot Tutorial](https://www.jac-lang.org/learn/examples/rag_chatbot/Overview/) - Building chatbots with document retrieval

**🔬 Research**: The research journey of MTP is available on [Arxiv](https://arxiv.org/abs/2405.08965).

## Quick Links

- [Getting Started Guide](https://www.jac-lang.org/learn/jac-byllm/with_llm/)
- [Model Configuration](https://www.jac-lang.org/learn/jac-byllm/model_declaration/)
- [Jac Language Documentation](https://www.jac-lang.org/)
- [GitHub Repository](https://github.com/jaseci-labs/jaseci)