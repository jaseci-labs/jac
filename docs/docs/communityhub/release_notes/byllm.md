# byLLM Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **byLLM** (formerly MTLLM). For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking_changes.md) page.

## byllm 0.4.14 (Unreleased)

- **Max Iterations for ReAct (`max_react_iterations`)**: Added a configurable limit for ReAct tool-calling loops via `by llm(max_react_iterations=3)` to prevent overly long or endless reasoning cycles. When the limit is reached, the model stops calling tools and returns a final answer based on the information gathered so far.

## byllm 0.4.13 (Latest Release)

## byllm 0.4.12

## byllm 0.4.9

- **LLM-Powered Graph Traversal (`visit by`)**: Introduced `visit [-->] by llm()` syntax enabling walkers to make intelligent traversal decisions. The LLM analyzes the semantic context of available nodes and selects which ones to visit based on the walker's purpose, bringing AI-powered decision making to graph navigation.

## byllm 0.4.8

- **Streaming with ReAct Tool Calling**: Implemented real-time streaming support for ReAct method when using tools. After tool execution completes, the LLM now streams the final synthesized answer token-by-token, providing the best of both worlds: structured tool calling with streaming responses.

## byllm 0.4.7

- **Custom Model Declaration**: Custom model interfaces can be defined by using the `BaseLLM` class that can be imported form `byllm.lib`. A guide for using this feature is added to [documentation](https://docs.jaseci.org/learn/jac-byllm/create_own_lm/).

## byllm 0.4.6

- **byLLM In-Memory Images**: byLLM Image class now accepts in-memory and path-like inputs (bytes/bytearray/memoryview, BytesIO/file-like, PIL.Image, Path), plus data/gs/http(s) URLs; auto-detects MIME (incl. WEBP), preserves URLs, and reads streams.

## byllm 0.4.5

- **byLLM Lazy Loading**: Refactored byLLM to support lazy loading by moving all exports to `byllm.lib` module. Users should now import from `byllm.lib` in Python (e.g., `from byllm.lib import Model, by`) and use `import from byllm.lib { Model }` in Jac code. This improves startup performance and reduces unnecessary module loading.
- **NonGPT Fallback for byLLM**: Implemented automatic fallback when byLLM is not installed. When code attempts to import `byllm`, the system will provide mock implementations that return random values using the `NonGPT.random_value_for_type()` utility.

## byllm 0.4.4

- **`is` Keyword for Semstrings**: Added support for using `is` as an alternative to `=` in semantic string declarations (e.g., `sem MyObject.value is "A value stored in MyObject"`).
- **byLLM Plugin Interface Improved**: Enhanced the byLLM plugin interface with `get_mtir` function hook interface and refactored the `by` decorator to use the plugin system, improving integration and extensibility.

## byllm 0.4.3

- **byLLM Enhancements**:
  - Fixed bug with Enums without values not being properly included in prompts (e.g., `enum Tell { YES, NO }` now works correctly).

## byllm 0.4.2

- **byLLM transition**: MTLLM has been transitioned to byLLM and PyPi package is renamed to `byllm`. Github actions are changed to push byllm PyPi. Alongside an mtllm PyPi will be pushed which installs latest `byllm` and produces a deprecation warning when imported as `mtllm`.
- **byLLM Feature Methods as Tools**: byLLM now supports adding methods of classes as tools for the llm using such as `tools=[ToolHolder.tool]`

## byllm 0.4.1

- **byLLM transition**: MTLLM has been transitioned to byLLM and PyPi package is renamed to `byllm`. Github actions are changed to push byllm PyPi. Alongside an mtllm PyPi will be pushed which installs latest `byllm` and produces a deprecation warning when imported as `mtllm`.

## mtllm 0.4.0

- **Removed LLM Override**: `function_call() by llm()` has been removed as it was introduce ambiguity in the grammer with LALR(1) shift/reduce error. This feature will be reintroduced in a future release with a different syntax.

## mtllm 0.3.8

- **Semantic Strings**: Introduced `sem` strings to attach natural language descriptions to code elements like functions, classes, and parameters. These semantic annotations can be used by Large Language Models (LLMs) to enable intelligent, AI-powered code generation and execution. (mtllm)
- **LLM Function Overriding**: Introduced the ability to override any regular function with an LLM-powered implementation at runtime using the `function_call() by llm()` syntax. This allows for dynamic, on-the-fly replacement of function behavior with generative models. (mtllm)

## Version 0.8.0
