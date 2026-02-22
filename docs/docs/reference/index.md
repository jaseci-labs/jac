# Reference

This section is the complete technical reference for Jac. Use the sidebar to navigate to the topic you need, or use the summaries below to find the right starting point.

---

## Language Specification

The language spec covers all core Jac constructs:

- **[Foundation](language/foundation.md)** - Syntax, types, literals, variables, scoping, operators, control flow, pattern matching
- **[Functions & Objects](language/functions-objects.md)** - Function declarations, `can` vs `def`, OOP, inheritance, enums, access modifiers, impl blocks
- **[Object-Spatial Programming](language/osp.md)** - Nodes, edges, walkers, `visit`, `report`, `disengage`, graph construction, data spatial queries
- **[Concurrency](language/concurrency.md)** - Async/await, `flow`/`wait` concurrent expressions, parallel operations
- **[Advanced Features](language/advanced.md)** - Error handling, testing blocks, filter/assign comprehensions, pipe operators

## Standalone References

- **[AI Integration](language/ai-integration.md)** - Meaning Typed Programming, `by llm()`, model configuration, tool calling, streaming, multimodal input
- **[Full-Stack](language/full-stack.md)** - Codespaces (`.sv.jac`, `.cl.jac`, `.na.jac`), components, npm packages, module system
- **[Deployment & Scaling](language/deployment.md)** - jac-scale, environment configuration, CORS, Kubernetes, production architecture

## Quick Lookup

Concise reference material for everyday development:

- **[Graph Operations](language/graph-operations.md)** - Node creation, connection patterns, traversal, edge filtering
- **[Walker Responses](language/walker-responses.md)** - The `.reports` array, response patterns, nested walker spawning
- **[Appendices](language/appendices.md)** - Complete keyword reference, operator quick reference, grammar, gotchas, migration guide

## Plugins

- **[byLLM](plugins/byllm.md)** - AI integration plugin powering `by llm()` and Meaning Typed Programming
- **[jac-client](plugins/jac-client.md)** - Full-stack frontend plugin with React-like components and Vite bundling
- **[jac-scale](plugins/jac-scale.md)** - Production deployment plugin with FastAPI, Redis, MongoDB, and Kubernetes support

## Tools

- **[CLI Commands](cli/index.md)** - Every `jac` subcommand with options and examples
- **[Configuration](config/index.md)** - Project settings via `jac.toml`
- **[Testing](testing.md)** - Test syntax, assertions, and CLI test commands

## Ecosystem

- **[Overview](language/ecosystem.md)** - The Jac plugin ecosystem and integration capabilities
- **[Python Integration](language/python-integration.md)** - Importing and using Python packages in Jac
- **[Library Mode](language/library-mode.md)** - Using Jac modules from Python with `jac jac2py`
