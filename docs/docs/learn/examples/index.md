# Examples Gallery

A curated collection of Jac examples organized by complexity level. Each example includes full source code, explanations, and step-by-step tutorials.

---

## Beginner

Start here if you're new to Jac. These examples demonstrate core language features.

| Example | Description | Key Features |
|---------|-------------|--------------|
| [Quick Examples](../example.md) | Standalone code snippets for key features | `by llm`, OSP basics, Python superset |
| [Jac in a Flash](../jac_in_a_flash.md) | Learn Jac syntax in 5 minutes | Variables, functions, control flow |

---

## Intermediate

Build your first complete applications with these step-by-step tutorials.

| Example | Description | Key Features |
|---------|-------------|--------------|
| [LittleX](littleX/tutorial.md) | Build a Twitter-like app in 200 lines | Nodes, walkers, `jac start`, graph traversal |
| [EmailBuddy](EmailBuddy/tutorial.md) | AI-powered email assistant | `by llm`, structured outputs, email integration |

---

## Advanced

Complex applications showcasing advanced Jac patterns and AI integration.

### Full-Stack Applications

| Example | Description | Key Features |
|---------|-------------|--------------|
| [RAG Chatbot](rag_chatbot/Overview.md) | Multimodal MCP chatbot with document search | MCP tools, vector search, multimodal AI |
| [RPG Level Generator](mtp_examples/rpg_game.md) | AI-powered game level generation | `by llm`, structured data types, procedural generation |
| [Fantasy Trading Game](mtp_examples/fantasy_trading_game.md) | AI-driven trading simulation | `by llm`, complex state management |

### Agentic AI

| Example | Description | Key Features |
|---------|-------------|--------------|
| [Friendzone Lite](agentic_ai/friendzone-lite/friendzone-lite.md) | Social AI agent | ReAct pattern, tool calling |
| [Aider Genius Lite](agentic_ai/aider-genius-lite/aider-genius-lite.md) | AI coding assistant | Code generation, tool integration |
| [Task Manager Lite](agentic_ai/task-manager-lite/task-manager-lite.md) | AI task management | Structured outputs, task decomposition |

---

## Reference Examples

The Jac repository includes comprehensive reference examples for every language feature:

```bash
# Location in repository
jac/examples/reference/
```

These include working `.jac` files with corresponding `.md` documentation and Python equivalents (`.py`) for comparison.

### Categories

| Category | Examples |
|----------|----------|
| **Basic Syntax** | Variables, expressions, control flow, functions |
| **Data Types** | Collections, enums, type annotations |
| **OSP Features** | Nodes, edges, walkers, graph operations |
| **AI Integration** | `by llm`, semantic strings |
| **Advanced** | Concurrency, context managers, generators |

---

## Running Examples

### Local Execution

```bash
# Run any example
jac run example.jac

# Run with session persistence
jac run example.jac -s my_session

# Clear persisted state if needed
rm -rf .jac/data/
```

### Server Mode

```bash
# Start API server
jac start example.jac

# API docs at http://localhost:8000/docs
```

### Testing Examples

```bash
# Run tests in an example
jac test example.jac

# Run all tests in directory
jac test -d examples/
```

---

## Contributing Examples

Want to add your own example? Follow these guidelines:

1. **Create a directory** under `docs/docs/learn/examples/`
2. **Include a tutorial.md** with step-by-step instructions
3. **Add working source code** in a `src/` subdirectory
4. **Test all code** before submitting
5. **Update mkdocs.yml** to add navigation entry

See the [Contributing Guide](../../contributing/index.md) for more details.
