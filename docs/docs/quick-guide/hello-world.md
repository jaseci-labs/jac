# Hello World

Write and run your first Jac program in 2 minutes.

---

## Your First Program

Create a file named `hello.jac`:

```jac
with entry {
    print("Hello, World!");
}
```

Run it:

```bash
jac hello.jac
```

Output:

```
Hello, World!
```

**Congratulations!** You just wrote your first Jac program.

---

## Understanding the Code

```jac
with entry {
    print("Hello, World!");
}
```

| Part | Meaning |
|------|---------|
| `with entry` | The program's starting point (like `main()` in other languages) |
| `{ }` | Code block (Jac uses braces, not indentation) |
| `print()` | Built-in function to output text |
| `;` | Statement terminator (required in Jac) |

---

## Add AI with `by llm()`

One of Jac's standout features is **compiler-integrated AI** using the **byLLM** plugin. Instead of writing prompts, you write typed functions and let the compiler handle the rest.

Create `sentiment.jac`:

```jac
import from byllm {Model};

glob llm = Model(model_name="gpt-4o");

enum Sentiment {
    POSITIVE,
    NEGATIVE,
    NEUTRAL
}

def analyze(text: str) -> Sentiment by llm();

with entry {
    result = analyze("I absolutely love this product!");
    print(result);
}
```

Run it (requires an API key):

```bash
export OPENAI_API_KEY="your-key-here"
jac sentiment.jac
```

Output:

```
Sentiment.POSITIVE
```

**What just happened?** The `by llm()` syntax tells Jac to delegate the function body to an LLM. The compiler extracts intent from:

- Function name: `analyze`
- Parameter: `text: str`
- Return type: `Sentiment` (an enum with three options)

No prompt engineering required. The types *are* the prompt.

→ Learn more in the [byLLM Quickstart](../tutorials/ai/quickstart.md)

---

## Run a Full-Stack App

Want to go beyond a single file? Jac can scaffold a complete full-stack application in one command.

With the `jac-client` plugin installed, run:

```bash
jac create example --use fullstack
cd example
jac add
jac start main.jac
```

This creates a full-stack project with a Jac backend and a React frontend, ready to go at `http://localhost:8000`.

---

## Run Community Jacpacks

[Jacpacks](https://github.com/jaseci-labs/jacpacks) are ready-made Jac project templates you can spin up instantly. Since `--use` accepts a URL, you can run any jacpack directly from GitHub:

```bash
jac create my-todo --use https://raw.githubusercontent.com/jaseci-labs/jacpacks/main/multi-user-todo-app/multi-user-todo-app.jacpack
cd my-todo
jac add
jac start main.jac
```

Here are some jacpacks to try:

| Jacpack | Description |
|---------|-------------|
| `multi-user-todo-app` | Full-stack authenticated todo application |
| `multi-user-todo-meals-app` | Todo app + AI meal planner powered by Jac's AI integration |
| `AI_Study_Helper` | Educational platform with specialized AI agents |
| `TasteTalk` | Restaurant feedback management system |
| `jac-gpt` | Documentation assistant for the Jac language |
| `jac-playground` | Browser-based Jac code editor |
| `Algo` | Voice-enabled personal AI assistant |

Want to try one with AI built in? The `multi-user-todo-meals-app` uses Jac's AI integration features to generate smart shopping lists with costs and nutritional info. It works out of the box with an Anthropic API key:

```bash
export ANTHROPIC_API_KEY="your-key-here"
jac create meals-app --use https://raw.githubusercontent.com/jaseci-labs/jacpacks/main/multi-user-todo-meals-app/multi-user-todo-meals-app.jacpack
cd meals-app
jac add
jac start main.jac
```

To use any of the other jacpacks, just swap the URL:

```bash
jac create my-app --use https://raw.githubusercontent.com/jaseci-labs/jacpacks/main/<jacpack-name>/<jacpack-name>.jacpack
```

---

## Next Steps

Ready for something more substantial?

- [Core Concepts](what-makes-jac-different.md) - Codespaces, OSP, and compiler-integrated AI
- [Build Your First App](../tutorials/first-app/part1-todo-app.md) - Build a complete full-stack AI app in Jac
- [Jac vs Traditional Stack](jac-vs-traditional-stack.md) - See how Jac compares side-by-side
- [Next Steps](next-steps.md) - Choose a learning path based on your goals
