# LLMDocs

Condensed Jac language reference materials optimized for LLM context windows. Use these to give language models comprehensive Jac knowledge for code generation.

## Versions

| Version | Size | Tokens | Description | Best For |
|---------|------|--------|-------------|----------|
| **Mini** | 4.2 KB | 1,390 | Complete Jac reference in 18 lines. **Recommended for most use cases.** | Production apps, API integration, graph operations |
| **Core** | 33 KB | 8,700 | Detailed reference with extensive examples. | Learning Jac, enterprise documentation needs |

*Token counts from OpenAI GPT-4o tokenizer*

**Start with Mini** - it covers everything for real applications.

## Downloads

- **Mini**: [llmdocs-jaseci-mini_v3.txt](https://raw.githubusercontent.com/kevinjin420/jaseci-llmdocs/main/release/0.3/llmdocs-jaseci-mini_v3.txt)
- **Core**: [llmdocs-jaseci-core_v3.txt](https://raw.githubusercontent.com/kevinjin420/jaseci-llmdocs/main/release/0.3/llmdocs-jaseci-core_v3.txt)

## Usage

### Claude Code and Command-Line Agents

```
# Jac Language Context
Include @llmdocs-jaseci-mini_v3.txt when working with .jac files
```

### Cursor

Add to `.cursorrules`:

```
When writing Jac code, reference llmdocs-jaseci-mini_v3.txt for syntax
```

## Coverage

### Mini (Recommended)

- Complete syntax reference
- Objects, nodes, edges, walkers
- Graph queries and traversal
- AI integration with byLLM
- Cloud APIs and endpoints
- Persistence and permissions
- WebSocket and webhook basics
- Common design patterns

### Core

Everything in Mini plus detailed examples and verbose explanations.

## Version Information

**Current Version:** v0.3

**Last Updated:** November 10, 2024

**Jac Compatibility:** 0.7.x+

## Next Steps

- Explore [AI Integration with byLLM](../jac-byllm/quickstart.md) for building AI-powered applications
- Learn about [Production deployment with jac-scale](../../production/index.md)
- Read the [Jac Book](../../jac_book/index.md) for comprehensive tutorials
