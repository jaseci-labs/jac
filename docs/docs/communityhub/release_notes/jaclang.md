# Jaclang Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jaclang**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking_changes.md) page.

## jaclang 0.9.4 (Unreleased)

- **`let` Keyword Removed**: The `let` keyword has been removed from Jaclang. Variable declarations now use direct assignment syntax (e.g., `x = 10` instead of `let x = 10`), aligning with Python's approach to variable binding.
- **Py2Jac Robustness Improvements**: Improved reliability of Python-to-Jac conversion with better handling of f-strings (smart quote switching, no keyword escaping in interpolations), match pattern class names, attribute access formatting (no extra spaces around dots), and nested docstrings in classes and functions.
- **Format Command Enhancements**: The `jac format` command now tracks and reports which files were actually changed during formatting. The summary output shows both total files processed and the count of files that were modified (e.g., `Formatted 10/12 '.jac' files (3 changed).`). Additionally, syntax errors encountered during formatting are now printed with full error details.
- **Py2Jac Stability**: Fixed conversion of Python code with augmented assignments and nested docstrings so generated Jac no longer redeclares targets or merges docstrings into following defs.
- **Support JS Switch Statement**: Javascript transpilation for switch statement is supported.
- **F-String Escape Sequence Fix**: Fixed a bug where escape sequences like `\n`, `\t`, etc. inside f-strings were not being properly decoded, causing literal backslash-n to appear in output instead of actual newlines. The fix correctly decodes escape sequences for f-string literal fragments in `unitree.py`.
- **Python `-m` Module Execution Support**: Added ability for Jac modules to be executed directly via `python -m module_name`. When jaclang is auto-imported at Python startup (via a `.pth` file like `jaclang_hook.pth`), both single-file Jac modules and Jac packages (with `__main__.jac`) can be run using Python's standard `-m` flag.
- **Use Keywords as variable**: Developers can now use any jaclang keywords as variable by using escape character `<>`. Example: `<>from`.
- **Props support**: Support Component props system with Python kwargs style with `props` keyword. Ex: `props.children`.
- **Standalone `.cl.jac` Module Detection**: `.cl.jac` files are now recognized as Jac modules both as standalone import targets (when no `.jac` exists) and as attachable client annexes.
- **Use Keywords as variable**: Developers can now use any jaclang keywords as variable by using escape character `<>`. Example: `<>from`.
- **Strings supported without escaping within jsx**: Strings supported without escaping within jsx. Example usage: `<h1> "Authentication" App </h1>`
- **Support output format for dot command**: Output format for dot command is supported. Example Usage: `jac dot filename.jac --format json`
- **Shared `impl/` Folder for Annex Discovery**: Impl files can now be organized in a shared `impl/` folder within the same directory as the target module. For example, `impl/foo.impl.jac` will be discovered and attached to `foo.jac`, alongside the existing discovery methods (same directory and module-specific `.impl/` folders).
- **Unified Plugin Configuration System**: Introduced a standardized configuration interface for Jac plugins through `jac.toml`. Plugins can now register configuration schemas via `get_plugin_metadata()` and `get_config_schema()` hooks, with settings defined under `[plugins.<plugin_name>]` sections. This replaces environment variable-based configuration with a centralized, type-safe approach. Applied to jac-client, jac-scale and jac-byllm plugins.

## jaclang 0.9.3 (Latest Release)

- **Fixed JSX Text Parsing for Keywords**: Fixed a parser issue where keywords like `to`, `as`, `in`, `is`, `for`, `if`, etc. appearing as text content within JSX elements would cause parse errors. The grammar now correctly recognizes these common English words as valid JSX text content.
- **Support iter for statement**: Iter for statement is supported in order to utilize traditional for loop in javascript.
- **JavaScript Export Semantics for Public Declarations**: Declarations explicitly annotated with `:pub` now generate JavaScript `export` statements. This applies to classes (`obj :pub`), functions (`def :pub`), enums (`enum :pub`), and global variables (`glob :pub`), enabling proper ES module exports in generated JavaScript code.
- **Cross-Language Type Checking for JS/TS Dependencies**: The type checker now supports loading and analyzing JavaScript (`.js`) and TypeScript (`.ts`, `.jsx`, `.tsx`) file dependencies when used with client-side (`cl`) imports. This enables type checking across language boundaries for files with client-language elements, allowing the compiler to parse and include JS/TS modules in the module hub for proper type resolution.
- **Formatter Improvements and Standardization**: Enhanced the Jac code formatter with improved consistency and standardization across formatting rules.

## jaclang 0.9.1

-**Side effect imports supported**: side effect imports supported which will help to inject css.

- **Plugin for sending static files**: Added extensible plugin system for sending static files, enabling custom static file serving strategies and integration with various storage backends.
- **Type Checking Enhancements**:
  - Added type checking support for object spatial codes including the connect operator
  - Added type checking support for assign comprehensions and filter comprehensions
  - Improved type inference from return statements
  - Fixed inheritance-based member lookup in type system by properly iterating through MRO (Method Resolution Order) chain
  - Improved synthesized `__init__` method generation for dataclasses to correctly collect parameters from all base classes in inheritance hierarchy
- **LSP Improvements**: Added "Go to Definition" support for `here` and `visitor` keywords in the language server

## jaclang 0.9.0

- **Generics TypeChecking**: Type checking for generics in vscode extension has implemented, i.e. `dict[int, str]` can be now checked by the lsp.
- **Plugin Architecture for Server Rendering**: Added extensible plugin system for server-side page rendering, allowing custom rendering engines and third-party templating integration with transform, cache, and customization capabilities.
- **Improvements to Runtime Error reporting**: Made various improvements to runtime error CLI reporting.
- **Node Spawn Walker supported**: Spawning walker on a node with `jac serve` is supported.

## jaclang 0.8.10

- **Frontend + Backend with `cl` Keyword (Experimental)**: Introduced a major experimental feature enabling unified frontend and backend development in a single Jac codebase. The new `cl` (client) keyword marks declarations for client-side compilation, creating a dual compilation pipeline that generates both Python (server) and pure JavaScript (client) code. Includes full JSX language integration for building modern web UIs, allowing developers to write React-style components directly in Jac with seamless interoperability between server and client code.
- **Optional Ability Names**: Ability declarations now support optional names, enabling anonymous abilities with event clauses (e.g., `can with entry { ... }`). When a name is not provided, the compiler automatically generates a unique internal name based on the event type and source location. This feature simplifies walker definitions by reducing boilerplate for simple entry/exit abilities.
- **LSP Threading Performance Improvements**: Updated the Language Server Protocol (LSP) implementation with improved threading architecture for better performance and responsiveness in the VS Code extension.
- **Parser Performance Optimization**: Refactored parser node tracking to use O(N) complexity instead of O(N²), drastically reducing parsing time for large files by replacing list membership checks with set-based ID lookups.
- **OPath Designation for Object Spatial Paths**: Moved Path designation for object spatial paths to OPath to avoid conflicts with Python's standard library `pathlib.Path`. This change ensures better interoperability when using Python's path utilities alongside Jac's object-spatial programming features.
- **Import System Refactoring**: Refactored and simplified the Jac import system to better leverage Python's PEP 302 and PEP 451 import protocols. Removed over-engineered custom import logic in favor of standard Python meta path finders and module loaders, improving reliability and compatibility.
- **Module Cache Synchronization Fix**: Fixed module cache synchronization issues between `JacMachine.loaded_modules` and `sys.modules` that caused test failures and module loading inconsistencies. The machine now properly manages module lifecycles while preserving special Python modules like `__main__`.
- **Formatted String Literals (f-strings)**: Added improved and comprehensive support for Python-style formatted string literals in Jac with full feature parity.
- **Switch Case Statement**: Switch statement is introduced and javascript style fallthrough behavior is also supported.

## jaclang 0.8.9

- **Typed Context Blocks (OSP)**: Fully implemented typed context blocks (`-> NodeType { }` and `-> WalkerType { }`) for Object-Spatial Programming, enabling conditional code execution based on runtime types.
- **Parser Infinite Loop Fix**: Fixed a major parser bug that caused infinite recursion when encountering malformed tuple assignments (e.g., `with entry { a, b = 1, 2; }`), preventing the parser from hanging.
- **Triple Quoted F-String Support**: Added support for triple quoted f-strings in the language, enabling multi-line formatted strings with embedded expressions (e.g., `f"""Hello {name}"""`).
- **Library Mode Interface**: Added new `jaclang.lib` module that provides a clean, user-friendly interface for accessing JacMachine functionality. This module auto-exposes all static methods from `JacMachineInterface` as module-level functions, making it easier to use Jac as a Python library.
- **Enhanced `jac2py` CLI Command**: The `jac2py` command now generates cleaner Python code suitable for library use with direct imports from `jaclang.lib` (e.g., `from jaclang.lib import Walker`), producing more readable and maintainable Python output.
- **Clean generator expression within function calls**: Enhanced the grammar to support generator expressions without braces in a function call. And python to jac conversion will also make it clean.
- **Support attribute pattern in Match Case**: With the latest bug fix, attribute pattern in match case is supported. Therefore developers use match case pattern like `case a.b.c`.
- **Py2Jac Empty File Support**: Added support for converting empty Python files to Jac code, ensuring the Py2Jac handles files with no content.
- **Formatter Enhancements**: Improved the Jac code formatter with several fixes and enhancements, including:
  - Corrected indentation issues in nested blocks and after comments
  - Removed extra spaces in statements like `assert`
  - Preserved docstrings without unintended modifications
  - Enhanced handling of long expressions and line breaks for better readability
- **VSCE Improvements**: Improved environment management and autocompletion in the Jac VS Code extension, enhancing developer experience and productivity.

## jaclang 0.8.8

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

## jaclang 0.8.7

- **Fix `jac run same_name_of_jac.py`**- there was a bug which only runs jac file if both jac and python files were having same name. It was fixed so that developers run python files which has same name as jac with `jac run` command. (Ex: `jac run example.jac`, `jac run example.py`)
- **Fix `jac run pythonfile.py` bugs**: Few bugs such as `init` is not found, `SubTag` ast node issue, are fixed. So that developers can run `jac run` of python files without these issues.
- **Fix `lambda self injection in abilities`**: Removed unintended `self` parameter in lambdas declared inside abilities/methods.
- **Fix `jac2py lambda annotations`**: Stripped type annotations from lambda parameters during jac2py conversion to ensure valid Python output while keeping them in Jac AST for type checking.

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

## jaclang 0.8.6

## jaclang 0.8.5

- **Removed LLM Override**: `function_call() by llm()` has been removed as it was introduce ambiguity in the grammer with LALR(1) shift/reduce error. This feature will be reintroduced in a future release with a different syntax.
- **Enhanced Python File Support**: The `jac run` command now supports direct execution of `.py` files, expanding interoperability between Python and Jac environments.
- **Jac-Streamlit Plugin**: Introduced comprehensive Streamlit integration for Jac applications with two new CLI commands:
  - `jac streamlit` - Run Streamlit applications written in Jac directly from `.jac` files
  - `jac dot_view` - Visualize Jac graph structures in interactive Streamlit applications with both static (pygraphviz)
- **Improved Windows Compatibility**: Fixed file encoding issues that previously caused `UnicodeDecodeError` on Windows systems, ensuring seamless cross-platform development.
- **Fixed CFG inaccuracies**: Fixed issues when handling If statements with no Else body where the else edge was not captured in the CFG (as a NOOP) causing a missing branch on the CFG of the UniiR. Also fixed inaccuracies when terminating CFG branches where return statements and HasVariables had unexpected outgoing edges which are now being removed. However, the return still keeps connected to following code which are in the same scope(body) which are dead-code.

- **CFG print tool for CLI**: The CFG for a given program can be printed as a dot graph by running `jac tool ir cfg. filename.jac` CLI command.

## jaclang 0.8.4

- **Support Spawning a Walker with List of Nodes and Edges**: Introduced the ability to spawn a walker on a list of nodes and edges. This feature enables initiating traversal across multiple graph elements simultaneously, providing greater flexibility and efficiency in handling complex graph structures.
- **Bug fix on supporting while loop with else part**: Now we are supporting while loop with else part.

## jaclang 0.8.3

- **JacMachine Interface Reorganization**: The machine and interface have been refactored to maintain a shared global state(similar to Python's `sys.modules`) removing the need to explicitly pass execution context and dramatically improving performance.
- **Native Jac Imports**: Native import statements can now be used to import Jac modules seamlessly into python code, eliminating the need to use `_.jac_import()`.
- **Unicode String Literal Support**: Fixed unicode character handling in string literals. Unicode characters like "", "○", emojis, and other international characters are now properly preserved during compilation instead of being corrupted into byte sequences.
- **Removed Ignore Statements**: The `ignore` keyword and ignore statements have been removed as this functionality can be achieved more elegantly by modifying path collection expressions directly in visit statements.

## jaclang 0.8.1

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
