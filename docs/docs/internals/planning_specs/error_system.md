# Jac Compiler Error Handling Subsystem

## 1. Introduction

This document describes the error handling subsystem for the Jac compiler. The system provides a robust, maintainable, and developer-friendly way to report, manage, and diagnose errors and warnings encountered during the various compilation phases (parsing, semantic analysis, code generation, etc.).

The system achieves the following objectives:
-   **Centralization**: A single source of truth for all error and warning definitions (codes, message templates).
-   **Clarity**: Consistent and informative error messages for the user.
-   **Maintainability**: Easier to add, modify, and track error types.
-   **Extensibility**: Ability to add richer diagnostic information (e.g., fix-it hints) in the future.
-   **Tooling Support**: Facilitate better integration with IDEs and other development tools.

## 2. System Overview

The error handling system uses an `Alert` class (`jaclang.compiler.passes.transform.Alert`) that supports centralized error codes.

-   Each `Transform` (base class for compiler passes) maintains its own `errors_had` and `warnings_had` lists.
-   Passes report errors using `log_error(ErrorCode, ...)` or `log_warning(ErrorCode, ...)` with centralized error codes.
-   These methods create `Alert` objects, storing the error code, formatted message, code location (`CodeLocInfo`), and the originating pass type.
-   Alerts from individual passes are also aggregated into global `errors_had` and `warnings_had` lists in the `JacProgram` instance.

## 3. Design

The system uses a simplified, co-located error definition approach where error codes, categories, and message templates are defined together in a single file.

### 3.1. Error Code Enumeration

**Location:** `jaclang.compiler.errors.error_definitions.py`

The `ErrorCode` enum provides centralized error codes organized by category:
-   **E0000-E0999**: General/Syntax errors (e.g., `SYNTAX_ERROR`, `UNEXPECTED_TOKEN`, `MISSING_SEMICOLON`)
-   **E1000-E1999**: Symbol Table errors (e.g., `SYMBOL_NOT_FOUND`, `DUPLICATE_SYMBOL_DECL`)
-   **E2000-E2999**: Type System errors (e.g., `TYPE_MISMATCH`, `TYPE_ASSIGNMENT_ERROR`)
-   **E3000-E3999**: Semantic Analysis errors (e.g., `INVALID_TARGET_CONTEXT`, `MODULE_NOT_FOUND`)
-   **E4000-E4999**: Code Generation errors (e.g., `CODEGEN_FAILED`, `BYTECODE_GEN_FAILED`)
-   **E5000-E5999**: Internal Compiler Errors (e.g., `ICE_PASS_ERROR`, `ICE_UNEXPECTED_NODE`)
-   **W0000-W0999**: Warnings (e.g., `UNUSED_VARIABLE`, `UNUSED_IMPORT`)

Each error code is defined with:
-   A unique identifier (e.g., `"E2002"` for `TYPE_ASSIGNMENT_ERROR`)
-   A category (e.g., `"type"`, `"syntax"`, `"symbol"`)
-   A message template with format placeholders
-   Helper methods `is_error()` and `is_warning()` to categorize the code

### 3.2. Error Definitions

All error information is co-located in `error_definitions.py`:

```python
TYPE_ASSIGNMENT_ERROR = ErrorDef(
    "E2002", "type",
    "Cannot assign {right_type} to {left_type}"
)
```

This single definition includes:
-   The error code string
-   The category
-   The message template with format placeholders

### 3.3. Alert Structure

**Location:** `jaclang.compiler.passes.transform.py`

The `Alert` class stores error information:

```python
class Alert:
    """Alert interface with centralized error codes."""

    def __init__(
        self,
        code: ErrorCode,
        loc: CodeLocInfo,
        from_pass: Type[Transform],
        args: Optional[Dict[str, Any]] = None,
    ):
        self.code: ErrorCode = code
        self.loc: CodeLocInfo = loc
        self.from_pass: Type[Transform] = from_pass
        self.args: Dict[str, Any] = args if args else {}
        self.msg: str = code.format_message(**self.args)
```

Key properties:
-   `code`: The `ErrorCode` enum value
-   `msg`: The formatted error message (automatically generated from template)
-   `loc`: Location information (`CodeLocInfo`)
-   `from_pass`: The transform pass that generated the alert
-   `args`: Arguments used for message formatting

### 3.4. Error Reporting Methods

The `Transform` class methods support error codes:

```python
def log_error(
    self,
    code: ErrorCode,
    node_override: Optional[UniNode] = None,
    **kwargs: object,
) -> None:
    """Log an error with centralized error codes.

    Args:
        code: The ErrorCode for this error
        node_override: Optional node to use for location instead of self.cur_node
        **kwargs: Arguments for error message template formatting
    """
```

**Example Usage:**

```python
from jaclang.compiler.errors import ErrorCode

# Using error codes with parameters
self.log_error(
    ErrorCode.TYPE_ASSIGNMENT_ERROR,
    right_type="int",
    left_type="str",
    node_override=assignment_node
)

# Using error codes without parameters
self.log_error(
    ErrorCode.MISSING_COLON,
    node_override=node
)

# Warnings
self.log_warning(
    ErrorCode.UNUSED_VARIABLE,
    name="temp",
    node_override=var_node
)
```

### 3.5. Runtime Validation

The system validates that all required parameters are provided when formatting error messages. If a parameter is missing, a helpful `ValueError` is raised:

```python
ErrorCode.TYPE_ASSIGNMENT_ERROR.format_message(right_type="int")
# Raises: ValueError: Error E2002: Missing required parameter(s): left_type.
#         Template requires: left_type, right_type
```

## 4. Benefits

-   **Simplified Code**: Single file (~400 lines) instead of multiple files (~1054 lines)
-   **Co-location**: Error code, category, and template defined together
-   **Easy Maintenance**: Adding a new error requires only one line
-   **Runtime Validation**: Helpful error messages if parameters are missing
-   **Standardization**: Error codes provide a clear, unambiguous way to identify specific issues
-   **Improved Diagnostics**: Formatted messages with contextual arguments provide more precise information
-   **Testability**: Easier to write tests that check for specific error codes
-   **Production Ready**: Error codes can be tracked, categorized, and used for analytics and monitoring

## 5. Usage Guide

### For Compiler Pass Developers

**Basic Usage:**
```python
from jaclang.compiler.errors import ErrorCode

self.log_error(
    ErrorCode.TYPE_ASSIGNMENT_ERROR,
    right_type=right_type,
    left_type=left_type,
    node_override=node
)
```

### Common Error Codes

-   `TYPE_ASSIGNMENT_ERROR`: Type mismatch in assignment
-   `SYMBOL_NOT_FOUND`: Undefined symbol
-   `MODULE_NOT_FOUND`: Import error
-   `ICE_PASS_ERROR`: Internal compiler error
-   `FORMATTING_ERROR`: Code formatting error

See `jaclang.compiler.errors.error_definitions.py` for the complete list.

### Adding a New Error

To add a new error, simply add one line to `error_definitions.py`:

```python
NEW_ERROR = ErrorDef(
    "E9999", "category",
    "Error message with {param1} and {param2}"
)
```

That's it! The system handles validation and formatting automatically.

## 6. Future Enhancements

-   **Error Recovery**: Implement mechanisms for certain passes to attempt recovery after an error.
-   **Structured Diagnostic Information**: Extend `Alert` to carry more structured diagnostic data.
-   **Localization**: The centralized string templates make it easier to add support for multiple languages.
-   **Fix-it Hints**: Add suggestions for how to fix common errors.
-   **Error Suppression**: Allow selective error suppression or promotion (e.g., treating warnings as errors).