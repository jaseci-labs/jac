# Jac Language Reference

> **The AI-Native Full-Stack Programming Language**
>
> *One Language for Backend, Frontend, and AI*

---

## How to Use This Reference

This is a comprehensive reference for the Jac programming language. Navigate using the sidebar or use browser search (Ctrl+F / Cmd+F) within each page.

**Conventions:**

- `monospace` -- Keywords, types, operators, and code
- **Bold** -- Key terms and concepts
- Code blocks are verified, executable examples
- Sections marked **(OSP)** are Object-Spatial Programming features

---

## Reference Sections

### [Part I: Foundation](foundation.md)

Core language concepts and syntax basics.

- Introduction
- Getting Started
- Language Basics
- Types and Values
- Variables and Scope
- Operators
- Control Flow

### [Part II: Functions and Objects](functions-objects.md)

Functions, classes, and object-oriented programming.

- Functions and Abilities
- Object-Oriented Programming
- Implementations and Forward Declarations

### [Part III: Object-Spatial Programming](osp.md)

Jac's unique graph-based programming paradigm.

- Introduction to OSP
- Nodes
- Edges
- Walkers
- Graph Construction
- Graph Traversal
- Data Spatial Queries
- Typed Context Blocks

### [Part IV: Full-Stack Development](full-stack.md)

Building complete applications with Jac.

- Module System
- Server-Side Development
- Client-Side Development (JSX)
- Server-Client Communication
- Authentication & Users
- Memory & Persistence
- Development Tools

### [Part V: AI Integration](ai-integration.md)

LLM integration and meaning-typed programming.

- Meaning Typed Programming
- Semantic Strings
- The `by` Operator and LLM Delegation
- Agentic AI Patterns

### [Part VI: Concurrency](concurrency.md)

Async programming and parallel execution.

- Async/Await
- Concurrent Expressions

### [Part VII: Advanced Features](advanced.md)

Error handling, testing, and advanced operators.

- Error Handling
- Testing
- Filter and Assign Comprehensions
- Pipe Operators

### [Part VIII: Ecosystem](ecosystem.md)

Tools, plugins, and interoperability.

- CLI Reference
- Plugin System
- Project Configuration
- Python Interoperability
- JavaScript/npm Interoperability
- **[Python Integration](python-integration.md)** - 5 adoption patterns, transpilation details

### [Part IX: Deployment and Scaling](deployment.md)

Production deployment with jac-scale.

- jac-scale Plugin
- Kubernetes Deployment
- Production Architecture
- **[Library Mode](library-mode.md)** - Pure Python with Jac runtime

### [Appendices](appendices.md)

Quick references and migration guides.

- Complete Keyword Reference
- Operator Quick Reference
- Grammar Summary
- Common Gotchas
- Migration from Python
- LLM Provider Reference

### Quick Reference

Focused reference pages for common patterns:

- **[Walker Responses](walker-responses.md)** - Understanding `.reports` patterns
- **[Graph Operations](graph-operations.md)** - Node creation, traversal, deletion

---

## Related Resources

### Tutorials

Step-by-step guides for learning Jac:

- [Language Basics](../../tutorials/language/basics.md) - Jac syntax from Python
- [Object-Spatial Programming](../../tutorials/language/osp.md) - Nodes, edges, walkers
- [Testing](../../tutorials/language/testing.md) - Writing and running tests
- [AI Integration](../../tutorials/ai/quickstart.md) - First byLLM function
- [Full-Stack Development](../../tutorials/fullstack/setup.md) - Building web apps

### Plugin References

Detailed API documentation for plugins:

- [byLLM Reference](../plugins/byllm.md) - AI/LLM integration
- [jac-client Reference](../plugins/jac-client.md) - Frontend development
- [jac-scale Reference](../plugins/jac-scale.md) - Production deployment

### Other References

- [CLI Reference](../cli/index.md) - Command-line interface
- [Configuration Reference](../config/index.md) - jac.toml settings
- [Testing Reference](../testing.md) - Test syntax and patterns
