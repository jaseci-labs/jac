# Jac Compiler Error Handling Subsystem

## 1. Introduction

This document describes the implemented error handling subsystem for the Jac compiler. The system provides a robust, maintainable, and developer-friendly way to report, manage, and diagnose errors and warnings encountered during the various compilation phases (parsing, semantic analysis, code generation, etc.).

The system achieves the following objectives:
-   **Centralization**: A single source of truth for all error and warning definitions (codes, message templates).
-   **Clarity**: Consistent and informative error messages for the user.
-   **Maintainability**: Easier to add, modify, and track error types.
-   **Extensibility**: Ability to add richer diagnostic information (e.g., fix-it hints) in the future.
-   **Tooling Support**: Facilitate better integration with IDEs and other development tools.

## 2. System Overview

The error handling system uses an `Alert` class (`jaclang.compiler.passes.transform.Alert`) that supports centralized error codes.

-   Each `Transform` (base class for compiler passes) maintains its own `errors_had` and `warnings_had` lists.
-   Passes report errors using `log_error(JacErrorCode, ...)` or `log_warning(JacErrorCode, ...)` with centralized error codes.
-   These methods create `Alert` objects, storing the error code, formatted message, code location (`CodeLocInfo`), and the originating pass type.
-   Alerts from individual passes are also aggregated into global `errors_had` and `warnings_had` lists in the `JacProgram` instance.
-   The system maintains backward compatibility with legacy string-based error messages.

## 3. Implemented Design

The system introduces a centralized error registry, standardized error codes, and an enhanced error reporting structure.

### 3.1. Error Code Enumeration

**Location:** `jaclang.compiler.errors.error_codes.py`

The `JacErrorCode` enum provides centralized error codes organized by category:

-   **E0000-E0999**: General/Syntax errors (e.g., `SYNTAX_ERROR`, `UNEXPECTED_TOKEN`, `MISSING_SEMICOLON`)
-   **E1000-E1999**: Symbol Table errors (e.g., `SYMBOL_NOT_FOUND`, `DUPLICATE_SYMBOL_DECL`)
-   **E2000-E2999**: Type System errors (e.g., `TYPE_MISMATCH`, `TYPE_ASSIGNMENT_ERROR`)
-   **E3000-E3999**: Semantic Analysis errors (e.g., `INVALID_TARGET_CONTEXT`, `MODULE_NOT_FOUND`)
-   **E4000-E4999**: Code Generation errors (e.g., `CODEGEN_FAILED`, `BYTECODE_GEN_FAILED`)
-   **E5000-E5999**: Internal Compiler Errors (e.g., `ICE_PASS_ERROR`, `ICE_UNEXPECTED_NODE`)
-   **W0000-W0999**: Warnings (e.g., `UNUSED_VARIABLE`, `UNUSED_IMPORT`)

Each error code has:
-   A unique identifier (e.g., `"E2002"` for `TYPE_ASSIGNMENT_ERROR`)
-   Helper methods `is_error()` and `is_warning()` to categorize the code

### 3.2. Error Message Templates

**Location:** `jaclang.compiler.errors.error_messages.py`

The `ERROR_MESSAGE_TEMPLATES` dictionary maps each `JacErrorCode` to a formatted message template using Python format string syntax.

Example:
```python
JacErrorCode.TYPE_ASSIGNMENT_ERROR: "Cannot assign {right_type} to {left_type}"
JacErrorCode.SYMBOL_NOT_FOUND: "Symbol '{name}' not found"
```

The `get_error_message(code, **kwargs)` function formats error messages using the templates and provided arguments.

### 3.3. Enhanced Alert Structure

**Location:** `jaclang.compiler.passes.transform.py`

The `Alert` class has been enhanced to support both the new error code system and legacy string messages:

```python
class Alert:
    """Alert interface with centralized error codes."""

    def __init__(
        self,
        msg_or_code: str | JacErrorCode,
        loc: CodeLocInfo,
        from_pass: Type[Transform],
        args: Optional[Dict[str, Any]] = None,
    ):
        # Supports both JacErrorCode and legacy string messages
        if isinstance(msg_or_code, JacErrorCode):
            self.code: JacErrorCode = msg_or_code
            self.msg: str = get_error_message(self.code, **self.args)
        else:
            # Legacy support
            self.code = JacErrorCode.SYNTAX_ERROR
            self.msg = str(msg_or_code)
```

Key properties:
-   `code`: The `JacErrorCode` enum value
-   `msg`: The formatted error message
-   `loc`: Location information (`CodeLocInfo`)
-   `from_pass`: The transform pass that generated the alert
-   `args`: Arguments used for message formatting

### 3.4. Updated Error Reporting Methods

The `Transform` class methods have been updated to support error codes:

```python
def log_error(
    self,
    msg_or_code: str | JacErrorCode,
    node_override: Optional[UniNode] = None,
    **kwargs: Any,
) -> None:
    """Log an error with centralized error codes.

    Supports both JacErrorCode (preferred) and legacy string messages.
    """
```

**Example Usage:**

```python
# Using error codes (preferred)
self.log_error(
    JacErrorCode.TYPE_ASSIGNMENT_ERROR,
    right_type="int",
    left_type="str",
    node_override=assignment_node
)

# Legacy string messages still work
self.log_error("Cannot assign int to str", node_override=assignment_node)
```

### 3.5. Backward Compatibility

The system maintains full backward compatibility:
-   Legacy string-based error messages are still accepted
-   Old code using `log_error("message")` continues to work
-   Legacy messages are automatically assigned `SYNTAX_ERROR` code

## 4. Benefits

-   **Standardization**: Error codes provide a clear, unambiguous way to identify specific issues.
-   **Maintainability**: Error messages are centrally managed, making them easier to update, correct, or translate.
-   **Improved Diagnostics**: Formatted messages with contextual arguments provide more precise information.
-   **Reduced Redundancy**: Eliminates scattered string literals for error messages across the codebase.
-   **Testability**: Easier to write tests that check for specific error codes rather than matching fragile message strings.
-   **Production Ready**: Error codes can be tracked, categorized, and used for analytics and monitoring.

## 5. Migration Guide

### For Compiler Pass Developers

**Before:**
```python
self.log_error(f"Cannot assign {right_type} to {left_type}", node)
```

**After:**
```python
from jaclang.compiler.errors import JacErrorCode

self.log_error(
    JacErrorCode.TYPE_ASSIGNMENT_ERROR,
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

See `jaclang.compiler.errors.error_codes.py` for the complete list.

## 6. Future Enhancements

-   **Error Recovery**: Implement mechanisms for certain passes to attempt recovery after an error.
-   **Structured Diagnostic Information**: Extend `Alert` to carry more structured diagnostic data.
-   **Localization**: The centralized string templates make it easier to add support for multiple languages.
-   **Fix-it Hints**: Add suggestions for how to fix common errors.
-   **Error Suppression**: Allow selective error suppression or promotion (e.g., treating warnings as errors).
