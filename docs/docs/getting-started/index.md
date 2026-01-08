# Getting Started with Jac

Welcome to Jac - a programming language designed for the AI era. Jac extends Python with powerful new paradigms while maintaining full compatibility with the Python ecosystem.

## What is Jac?

Jac is a **Python superset** that introduces three key innovations:

1. **Object-Spatial Programming (OSP)**: Work with graph-based data structures using nodes, edges, and walkers as first-class language constructs
2. **AI-First Design**: Native LLM integration via the `by llm()` syntax - no prompt engineering required
3. **Scale-Native Execution**: Write once, run anywhere - from local development to cloud deployment without code changes

## Quick Start

### 1. Install Jac

```bash
# Create a virtual environment (recommended)
python -m venv jac-env
source jac-env/bin/activate  # Linux/Mac
# jac-env\Scripts\activate   # Windows

# Install Jac
pip install jaclang

# Verify installation
jac --version
```

### 2. Hello World

Create a file named `hello.jac`:

```jac
with entry {
    print("Hello, Jac World!");
}
```

Run it:

```bash
jac run hello.jac
```

Output:

```
Hello, Jac World!
```

### 3. Your First Graph Program

Here's a taste of Object-Spatial Programming:

```jac
node Person {
    has name: str;
}

with entry {
    # Create nodes connected to root
    root ++> Person(name="Alice");
    root ++> Person(name="Bob");

    # Query all Person nodes from root
    for person in [root-->(`?Person)] {
        print(f"Hello, {person.name}!");
    }
}
```

Run it:

```bash
jac run hello_osp.jac
```

Output:

```
Hello, Alice!
Hello, Bob!
```

## Learn More

| Resource | Description |
|----------|-------------|
| [Installation Guide](../learn/installation.md) | Detailed setup with IDE configuration |
| [Introduction to Jac](../learn/tour.md) | Core concepts and philosophy |
| [Quickstart Tutorial](../learn/quickstart.md) | Build a complete application |
| [The Jac Book](../jac_book/index.md) | Comprehensive learning resource |

## Who is Jac For?

- **Startups**: Rapid prototyping with one language for frontend, backend, and AI
- **AI/ML Engineers**: Build LLM agents and agentic workflows naturally
- **Full-Stack Developers**: Modern language features with Python ecosystem access
- **Students**: Approachable on-ramp to AI development

## When to Use Jac

Jac excels when:

- Your problem domain involves **connected data** (social networks, knowledge graphs)
- You need **LLMs deeply integrated** into your application logic
- You want to **reduce DevOps overhead** with auto-generated APIs
- You prefer **cleaner syntax** with mandatory typing and modern features
