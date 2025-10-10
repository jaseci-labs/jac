# Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of Jac and Jaseci. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](./breaking_changes.md) page.


## jaclang 0.8.10 / jac-cloud 0.2.10 / byllm 0.4.5 (Unreleased)

## jaclang 0.8.9 / jac-cloud 0.2.9 / byllm 0.4.4 (Latest Release)

- **Typed Context Blocks (OSP)**: Fully implemented typed context blocks (`-> NodeType { }` and `-> WalkerType { }`) for Object-Spatial Programming, enabling conditional code execution based on runtime types.
- **Parser Infinite Loop Fix**: Fixed a major parser bug that caused infinite recursion when encountering malformed tuple assignments (e.g., `with entry { a, b = 1, 2; }`), preventing the parser from hanging.
- **Triple Quoted F-String Support**: Added support for triple quoted f-strings in the language, enabling multi-line formatted strings with embedded expressions (e.g., `f"""Hello {name}"""`).
- **`is` Keyword for Semstrings**: Added support for using `is` as an alternative to `=` in semantic string declarations (e.g., `sem MyObject.value is "A value stored in MyObject"`).
- **Library Mode Interface**: Added new `jaclang.lib` module that provides a clean, user-friendly interface for accessing JacMachine functionality in library mode. This module auto-exposes all static methods from `JacMachineInterface` as module-level functions, making it easier to use Jac as a Python library.
- **New `jac2lib` CLI Command**: Introduced `jac2lib` command that generates cleaner Python code suitable for library use. Unlike `jac2py` which uses aliased imports (e.g., `_jl.Walker`), `jac2lib` generates direct imports from `jaclang.lib` (e.g., `from jaclang.lib import Walker`), producing more readable and maintainable Python output.
- **byLLM Plugin Interface Improved**: Enhanced the byLLM plugin interface with `get_mtir` function hook interface and refactored the `by` decorator to use the plugin system, improving integration and extensibility.
- **Clean generator expression within function calls**: Enhanced the grammar to support generator expressions without braces in a function call. And python to jac conversion will also make it clean.
- **Support attribute pattern in Match Case**: With the latest bug fix, attribute pattern in match case is supported. Therefore developers use match case pattern like `case a.b.c`.
- **Py2Jac Empty File Support**: Added support for converting empty Python files to Jac code, ensuring the Py2Jac handles files with no content.
- **Formatter Enhancements**: Improved the Jac code formatter with several fixes and enhancements, including:
  - Corrected indentation issues in nested blocks and after comments
  - Removed extra spaces in statements like `assert`
  - Preserved docstrings without unintended modifications
  - Enhanced handling of long expressions and line breaks for better readability
- **VSCE Improvements**: Improved environment management and autocompletion in the Jac VS Code extension, enhancing developer experience and productivity.

## jaclang 0.8.8 / jac-cloud 0.2.8 / byllm 0.4.3

- **Better Syntax Error Messages**: Initial improvements to syntax error diagnostics, providing clearer and more descriptive messages that highlight the location and cause of errors (e.g., `Missing semicolon`).
- **Check Statements Removed**: The `check` keyword has been removed from Jaclang. All testing functionality previously provided by `check` statements is now handled by `assert` statements within test blocks. Assert statements now behave differently depending on context: in regular code they raise `AssertionError` exceptions, while within `test` blocks they integrate with Jac's testing framework to report test failures. This unification simplifies the language by using a single construct for both validation and testing purposes.
- **Jac Import of Python Files**: This upgrade allows Python files in the current working directory to be imported using the Jac import system by running `export JAC_PYFILE_RAISE=true`. To extend Jac import functionality to all Python files, including those in site-packages, developers can enable it by running `export JAC_PYFILE_RAISE_ALL=true`.
- **Consistent Jac Code Execution**: Fixed an issue allowing Jac code to be executed both as a standalone program and as an application. Running `jac run` now executes the `main()` function, while `jac serve` launches the application without invoking `main()`.
- **Run transformed pytorch codes**: With `export JAC_PREDYNAMO_PASS=true`, pytorch breaking if statements will be transformed into non breaking torch.where statements. It improves the efficiency of pytorch programs.
- **Complete Python Function Parameter Syntax Support**: Added full support for advanced Python function parameter patterns including positional-only parameters (`/` separator), keyword-only parameters (`*` separator without type hints), and complex parameter combinations (e.g., `def foo(a, b, /, *, c, d=1, **kwargs): ...`). This enhancement enables seamless Python-to-Jac conversion (`py2jac`) by supporting the complete Python function signature syntax.
- **Type Checking Enhancements**:
  - Added support for `Self` type resolution
  - Enabled method type checking for tools
  - Improved inherited symbol resolution (e.g., `Cat` recognized as subtype of `Animal`)
  - Added float type validation
  - Implemented parameter–argument matching in function calls
  - Enhanced call expression parameter type checking
  - Enhanced import symbol type resolution for better type inference and error detection
- **VSCE Improvements**:
  - Language Server can now be restarted without requiring a full VS Code window reload
  - Improved environment handling: prompts users to select a valid Jac environment instead of showing long error messages
- **Formatter Bug Fixes**:
  - Fixed `if/elif/else` expression formatting
  - Improved comprehension formatting (list/dict/set/gen)
  - Corrected decorator and boolean operator formatting
  - Fixed function args/calls formatting (removed extra commas/spaces)
  - Fixed index slice spacing and redundant atom units
- **byLLM Enhancements**:
  - Fixed bug with Enums without values not being properly included in prompts (e.g., `enum Tell { YES, NO }` now works correctly).

## jaclang 0.8.7 / jac-cloud 0.2.7 / byllm 0.4.2

- **byLLM transition**: MTLLM has been transitioned to byLLM and PyPi package is renamed to `byllm`. Github actions are changed to push byllm PyPi. Alongside an mtllm PyPi will be pushed which installs latest `byllm` and produces a deprecation warning when imported as `mtllm`.
- **Fix `jac run same_name_of_jac.py`**- there was a bug which only runs jac file if both jac and python files were having same name. It was fixed so that developers run python files which has same name as jac with `jac run` command. (Ex: `jac run example.jac`, `jac run example.py`)
- **Fix `jac run pythonfile.py` bugs**: Few bugs such as `init` is not found, `SubTag` ast node issue, are fixed. So that developers can run `jac run` of python files without these issues.
- **Fix `lambda self injection in abilities`**: Removed unintended `self` parameter in lambdas declared inside abilities/methods.
- **Fix `jac2py lambda annotations`**: Stripped type annotations from lambda parameters during jac2py conversion to ensure valid Python output while keeping them in Jac AST for type checking.
- **byLLM Feature Methods as Tools**: byLLM now supports adding methods of classes as tools for the llm using such as `tools=[ToolHolder.tool]`

- **TypeChecker Diagnostics**: Introduced type checking capabilities to catch errors early and improve code quality! The new type checker pass provides static analysis including:
  - **Type Annotation Validation**: Checks explicit type annotations in variable assignments for type mismatches
  - **Type Inference**: Simple type inference for assignments with validation against declared types
  - **Member Access Type Checking**: Type checking for member access patterns (e.g., `obj.field.subfield`)
  - **Import Symbol Type Checking**: Type inference for imported symbols (Basic support)
  - **Function Call Return Type Validation**: Return type checking for function calls (parameter validation not yet supported)
  - **Magic Method Support**: Type checking for special methods like `__call__`, `__add__`, `__mul__`
  - **Binary Operation Type Checking**: Operator type validation with simple custom operator support
  - **Class Instantiation**: Type checking for class constructor calls and member access
  - **Cyclic Symbol Detection**: Detection of self-referencing variable assignments
  - **Missing Import Detection**: Detection of imports from non-existent modules

  Type errors now appear in the Jac VS Code extension (VSCE) with error highlighting during editing.

- **VSCE Semantic Token Refresh Optimization**: Introduced a debounce mechanism for semantic token refresh in the Jac Language Server, significantly improving editor responsiveness:
  - Reduces redundant deep checks during rapid file changes
  - Optimizes semantic token updates for smoother editing experience

- **Windows LSP Improvements**: Fixed an issue where outdated syntax and type errors persisted on Windows. Now, only current errors are displayed

## jaclang 0.8.6 / jac-cloud 0.2.6 / byllm 0.4.1

- **byLLM transition**: MTLLM has been transitioned to byLLM and PyPi package is renamed to `byllm`. Github actions are changed to push byllm PyPi. Alongside an mtllm PyPi will be pushed which installs latest `byllm` and produces a deprecation warning when imported as `mtllm`.

## jaclang 0.8.5 / jac-cloud 0.2.5 / mtllm 0.4.0

- **Jac Cloud Hot Reload**: Introduced the ability to enable development mode like uvicorn by adding `--reload` in `jac serve`. This supports targetting specific directories by using `--watch path/to/dir1,path/to/dir2` (comma separated).
- **Dynamic Runtime Walker Endpoint**: Fixes auto-generated endpoints for walkers created at runtime.
- **Removed LLM Override**: `function_call() by llm()` has been removed as it was introduce ambiguity in the grammer with LALR(1) shift/reduce error. This feature will be reintroduced in a future release with a different syntax.
- **Enhanced Python File Support**: The `jac run` command now supports direct execution of `.py` files, expanding interoperability between Python and Jac environments.
- **Jac-Streamlit Plugin**: Introduced comprehensive Streamlit integration for Jac applications with two new CLI commands:
  - `jac streamlit` - Run Streamlit applications written in Jac directly from `.jac` files
  - `jac dot_view` - Visualize Jac graph structures in interactive Streamlit applications with both static (pygraphviz)
- **Improved Windows Compatibility**: Fixed file encoding issues that previously caused `UnicodeDecodeError` on Windows systems, ensuring seamless cross-platform development.
- **Jac Clouds Traverse API**: Introduced the ability to traverse graph. This API support control of the following:
  - source - Starting node/edge. Defaults to root
  - detailed - If response includes archetype context. Defaults to False
  - depth - how deep the traversal from source. Count includes edges. Defaults to 1
  - node_types - Node filter by name. Defaults to no filter
  - edge_types - Edge filter by name. Defaults to no filter
- **Dedicated Memory commit interface.**: Introduced the interface to commit memory to db at runtime. Previously, we only have it on jac-cloud but we generalized it and support it for both jac and jac-cloud.

- **Fixed CFG inaccuracies**: Fixed issues when handling If statements with no Else body where the else edge was not captured in the CFG (as a NOOP) causing a missing branch on the CFG of the UniiR. Also fixed inaccuracies when terminating CFG branches where return statements and HasVariables had unexpected outgoing edges which are now being removed. However, the return still keeps connected to following code which are in the same scope(body) which are dead-code.

- **CFG print tool for CLI**: The CFG for a given program can be printed as a dot graph by running `jac tool ir cfg. filename.jac` CLI command.

## jaclang 0.8.4 / jac-cloud 0.2.4 / mtllm 0.3.9

- **Support Spawning a Walker with List of Nodes and Edges**: Introduced the ability to spawn a walker on a list of nodes and edges. This feature enables initiating traversal across multiple graph elements simultaneously, providing greater flexibility and efficiency in handling complex graph structures.
- **save(...) should not override root in runtime**: The previous version bypassed access validation because the target archetype root was overridden by the current root, simulating ownership of the archetype.
- **Support Custom Access Validation**: Introduced the ability to override access validation. `Node`/`Edge` can override `__jac_access__` reserved function (`builtin`) to have a different way of validating access. Either you cross-check it by current attribute, check from db or global vars or by just returning specific access level. [PR#1524](https://github.com/jaseci-labs/jaseci/pull/1524)
- **Get all Root Builtin Method**: Introduced `allroots` builtin method to get all the roots available in the memory. Developers can get all the roots in the memory/ database by calling `allroots()` method.
- **Permission Update Builtin Methods**: Introduced `grant`, `revoke` builtin methods, `NoPerm`, `ReadPerm`, `ConnectPerm`, `WritePerm` builtin enums, to give the permission to a node or revoke the permission. Developers can use them by calling `grant(node_1, ConnectPerm)` or `revoke(node_1)` method.
- **`jac create_system_admin` cli now support local db**: `DATABASE_HOST` are now not required when creating system admin.

- **Bug fix on supporting while loop with else part**: Now we are supporting while loop with else part.

## jaclang 0.8.3 / jac-cloud 0.2.3 / mtllm 0.3.8

- **Semantic Strings**: Introduced `sem` strings to attach natural language descriptions to code elements like functions, classes, and parameters. These semantic annotations can be used by Large Language Models (LLMs) to enable intelligent, AI-powered code generation and execution. (mtllm)
- **LLM Function Overriding**: Introduced the ability to override any regular function with an LLM-powered implementation at runtime using the `function_call() by llm()` syntax. This allows for dynamic, on-the-fly replacement of function behavior with generative models. (mtllm)
- **JacMachine Interface Reorganization**: The machine and interface have been refactored to maintain a shared global state—similar to Python's `sys.modules`—removing the need to explicitly pass execution context and dramatically improving performance.
- **Async Walker Support**: Introduced comprehensive async walker functionality that brings Python's async/await paradigm to object-spatial programming. Async walkers enable non-blocking spawns during graph traversal, allowing for concurrent execution of multiple walkers and efficient handling of I/O-bound operations.
- **Native Jac Imports**: Native import statements can now be used to import Jac modules seamlessly into python code, eliminating the need to use `_.jac_import()`.
- **Unicode String Literal Support**: Fixed unicode character handling in string literals. Unicode characters like "✓", "○", emojis, and other international characters are now properly preserved during compilation instead of being corrupted into byte sequences.
- **Removed Ignore Statements**: The `ignore` keyword and ignore statements have been removed as this functionality can be achieved more elegantly by modifying path collection expressions directly in visit statements.

## jaclang 0.8.1 / jac-cloud 0.2.1 / mtllm 0.3.6

- **Function Renaming**: The `dotgen` built-in function has been renamed to `printgraph`. This change aims to make the function's purpose clearer, as `printgraph` more accurately reflects its action of outputting graph data. It can output in DOT format and also supports JSON output via the `as_json=True` parameter. Future enhancements may include support for other formats like Mermaid.
- **Queue Insertion Index for Visit Statements**: Visit statements now support queue insertion indices (e.g., `visit:0: [-->]` for depth-first, `visit:-1: [-->]` for breadth-first) that control where new destinations are inserted in the walker's traversal queue. Any positive or negative index can be used, enabling fine-grained control over traversal patterns and supporting complex graph algorithms beyond simple depth-first or breadth-first strategies.
- **Edge Ability Execution Semantics**: Enhanced edge traversal behavior with explicit edge references. By default, `[-->]` returns connected nodes, while `[edge -->]` returns edge objects. When walkers visit edges explicitly using `visit [edge -->]`, abilities are executed on both the edge and its connected node. Additionally, spawning a walker on an edge automatically queues both the edge and its target node for processing, ensuring complete traversal of the topological structure.
- **Jac Imports Execution**: Jac imports (`Jac.jac_import`) now run in a Python-like interpreter mode by default. Full compilation with dependency inclusion can only occur when explicitly calling `compile` from the `JacProgram` object.
- **Concurrent Execution with `flow` and `wait`**: Introduced `flow` and `wait` keywords for concurrent expressions. `flow` initiates parallel execution of expressions, and `wait` synchronizes these parallel operations. This enables efficient parallel processing and asynchronous operations directly within Jac with separate (and better) semantics than python's async/await.

## Version 0.8.0

- **`impl` Keyword for Implementation**: Introduced the `impl` keyword for a simpler, more explicit way to implement abilities and methods for objects, nodes, edges, and other types, replacing the previous colon-based syntax.
- **Updated Inheritance Syntax**: Changed the syntax for specifying inheritance from colons to parentheses (e.g., `obj Car(Vehicle)`) for better alignment with common object-oriented programming languages.
- **`def` Keyword for Functions**: The `def` keyword is now used for traditional Python-like functions and methods, while `can` is reserved for object-spatial abilities.
- **`visitor` Keyword**: Introduced the `visitor` keyword to reference the walker context within nodes/edges, replacing the ambiguous use of `here` in such contexts. `here` is now used only in walker abilities to reference the current node/edge.
- **Lambda Syntax Update**: The lambda syntax has been updated from `with x: int can x;` to `lambda x: int: x * x;`, aligning it more closely with Python's lambda syntax.
- **Object-Spatial Arrow Notation Update**: Typed arrow notations `-:MyEdge:->` and `+:MyEdge:+>` are now `->:MyEdge:->` and `+>:MyEdge:+>` respectively, to avoid conflicts with Python-style list slicing.
- **Import `from` Syntax Update**: The syntax for importing specific modules from a package now uses curly braces (e.g., `import from utils { helper, math_utils }`) for improved clarity.
- **Auto-Resolved Imports**: Removed the need for explicit language annotations (`:py`, `:jac`) in import statements; the compiler now automatically resolves imports.
- **Permission API Renaming**: The `Jac.restrict` and `Jac.unrestrict` interfaces have been renamed to `Jac.perm_revoke` and `Jac.perm_grant` respectively, for better clarity on their actions.
- **Permission API Renaming**: The `Jac.restrict` and `Jac.unrestrict` interfaces have been renamed to `Jac.perm_revoke` and `Jac.perm_grant` respectively, for better clarity on their actions.
