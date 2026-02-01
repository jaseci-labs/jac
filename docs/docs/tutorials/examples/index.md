# Examples Gallery

Complete Jac applications to study, learn from, and build upon. Each example includes full source code, explanations, and step-by-step guidance.

---

!!! tip "Before diving in"
    Each example lists the Jac concepts it uses and links to where you can learn them. If an example uses a concept you haven't seen, follow the linked tutorial first.

## Featured Examples

### LittleX - Social Media Platform

Build a Twitter-like app in **200 lines of code**.

| | |
|---|---|
| **Difficulty** | Intermediate |
| **Features** | Nodes, walkers, edges, graph traversal, `jac start` |
| **Learn** | How to model social relationships as graphs |

[Start LittleX Tutorial →](littlex.md)

---

### EmailBuddy - AI Email Assistant

An intelligent email assistant powered by LLMs.

| | |
|---|---|
| **Difficulty** | Intermediate |
| **Features** | `by llm`, structured outputs, tool calling |
| **Learn** | How to build agentic AI applications |

[Start EmailBuddy Tutorial →](emailbuddy.md)

---

### RAG Chatbot - Document Q&A

A multimodal chatbot with document search and retrieval.

| | |
|---|---|
| **Difficulty** | Advanced |
| **Features** | MCP tools, vector search, retrieval-augmented generation |
| **Learn** | How to build knowledge-based AI systems |

[Start RAG Chatbot Tutorial →](rag-chatbot.md)

---

### RPG Level Generator

AI-powered procedural game level generation.

| | |
|---|---|
| **Difficulty** | Advanced |
| **Features** | `by llm`, structured data types, game logic |
| **Learn** | How to use AI for creative content generation |

[Start RPG Generator Tutorial →](rpg.md)

---

## More Examples

### Agentic AI Applications

| Example | Description |
|---------|-------------|
| [Friendzone Lite](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm/examples/agentic_ai/friendzone-lite) | Social AI agent with ReAct pattern |
| [Aider Genius Lite](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm/examples/agentic_ai/aider-genius-lite) | AI coding assistant |
| [Task Manager Lite](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm/examples/agentic_ai/task-manager-lite) | AI task management |

### Game Examples

| Example | Description |
|---------|-------------|
| [Fantasy Trading Game](https://github.com/Jaseci-Labs/jaseci/tree/main/jac-byllm/examples/mtp_examples/fantasy_trading_game) | AI-driven trading simulation |

---

## Running Examples

### From Source

```bash
# Clone the repository
git clone https://github.com/Jaseci-Labs/jaseci.git
cd jaseci/examples

# Run an example
jac example_name/main.jac
```

### As API Server

```bash
# Start the example as an API
jac start example_name/main.jac

# View API documentation
open http://localhost:8000/docs
```

### Running Tests

```bash
# Test an example
jac test example_name/main.jac

# Test all examples in directory
jac test -d examples/
```

---

## Example Structure

Each example follows this structure:

```
example_name/
├── main.jac           # Main application code
├── main.impl.jac      # Implementation details (optional)
├── main.test.jac      # Tests
├── README.md          # Documentation
└── requirements.txt   # Python dependencies (if needed)
```

---

## Contributing Examples

Want to share your Jac project?

1. Create a working example with tests
2. Write a tutorial explaining the key concepts
3. Submit a pull request

See the [Contributing Guide](../../community/contributing.md) for details.

---

## Reference Examples

The Jac repository includes comprehensive reference examples for every language feature:

```bash
jac/examples/reference/
├── basic_syntax/      # Variables, functions, control flow
├── data_types/        # Collections, enums, types
├── osp_features/      # Nodes, edges, walkers
├── ai_integration/    # by llm, semantic strings
└── advanced/          # Concurrency, generators
```

Each reference example includes:

- Working `.jac` source code
- Markdown documentation
- Python equivalent for comparison
