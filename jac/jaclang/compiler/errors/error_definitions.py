"""Centralized error definitions with type-safe parameters.

This module provides a simplified error system where error codes, categories,
and message templates are defined together in one place. This reduces code
from ~940 lines across 3 files to ~250 lines in this single file.

Each error is defined with:
- Error code (e.g., "E2002")
- Category (e.g., "type", "syntax", "symbol")
- Message template (with format placeholders)

Runtime validation ensures required parameters are provided.
"""

from dataclasses import dataclass
from enum import Enum


@dataclass(frozen=True)
class ErrorDef:
    """Complete error definition with code, category, and message template.

    All information about an error is defined in one place:
    - Error code (e.g., "E2002")
    - Category (e.g., "type", "syntax", "symbol")
    - Message template (with format placeholders)
    """

    code: str
    category: str
    template: str

    def format(self, **kwargs: object) -> str:
        """Format the error message with parameters.

        Validates that all required parameters are provided and formats
        the message template. Raises ValueError with helpful message if
        parameters are missing.

        Args:
            **kwargs: Parameters for message formatting (names match template placeholders)

        Returns:
            Formatted error message string

        Raises:
            ValueError: If required parameters are missing
        """
        import string

        # Extract required parameters from template
        formatter = string.Formatter()
        required_params = {
            name for _, name, _, _ in formatter.parse(self.template) if name
        }

        # Check for missing parameters
        provided_params = set(kwargs.keys())
        missing = required_params - provided_params

        if missing:
            raise ValueError(
                f"Error {self.code}: Missing required parameter(s): {', '.join(sorted(missing))}. "
                f"Template requires: {', '.join(sorted(required_params))}"
            )

        # Format the message
        try:
            # Filter to only use parameters that are actually in the template
            filtered_kwargs = {k: v for k, v in kwargs.items() if k in required_params}
            return self.template.format(**filtered_kwargs)
        except (KeyError, ValueError) as e:
            raise ValueError(
                f"Error {self.code}: Failed to format message: {e}. "
                f"Template: {self.template}, Provided: {kwargs}"
            ) from e


class ErrorCode(Enum):
    """Centralized error codes with embedded definitions.

    Each enum member is an ErrorDef containing all information about that error.
    Errors are organized by category with numeric ranges:
    - E0000-E0999: General/Syntax errors
    - E1000-E1999: Symbol Table errors
    - E2000-E2999: Type System errors
    - E3000-E3999: Semantic Analysis errors
    - E4000-E4999: Code Generation errors
    - E5000-E5999: Internal Compiler Errors
    - W0000-W0999: Warnings
    """

    # ============================================================================
    # General/Syntax Errors (E0000-E0999)
    # ============================================================================
    SYNTAX_ERROR = ErrorDef("E0001", "syntax", "Syntax error{message_suffix}")
    UNEXPECTED_TOKEN = ErrorDef("E0002", "syntax", "Unexpected token: {token}")
    UNEXPECTED_EOF = ErrorDef("E0003", "syntax", "Unexpected end of file")
    INVALID_CHARACTER = ErrorDef("E0004", "syntax", "Invalid character: {char}")
    MISSING_COLON = ErrorDef("E0005", "syntax", "Missing colon")
    MISSING_SEMICOLON = ErrorDef("E0006", "syntax", "Missing semicolon")
    MISSING_CLOSING_BRACE = ErrorDef("E0007", "syntax", "Missing closing brace '}}'")
    MISSING_CLOSING_PAREN = ErrorDef(
        "E0008", "syntax", "Missing closing parenthesis ')'"
    )
    MISSING_CLOSING_BRACKET = ErrorDef("E0009", "syntax", "Missing closing bracket ']'")
    INVALID_INDENTATION = ErrorDef("E0010", "syntax", "Invalid indentation")
    MISSING_TOKEN = ErrorDef("E0011", "syntax", "Missing {token}")
    INCOMPLETE_MEMBER_ACCESS = ErrorDef("E0012", "syntax", "Incomplete member access")
    INVALID_PARSE_TREE = ErrorDef(
        "E0013", "syntax", "Internal Compiler Error, Invalid Parse Tree!"
    )
    INVALID_ASYNC_ARCHETYPE = ErrorDef(
        "E0014", "syntax", "Expected async archetype to be walker, but got {arch_type}"
    )
    INVALID_FUNCTION_PARAMETERS = ErrorDef(
        "E0015", "syntax", "Invalid syntax in function parameters: '{details}'"
    )
    INVALID_FUNCTION_PARAMETERS_ORDER = ErrorDef(
        "E0016", "syntax", "Invalid syntax in function parameters: '{details}'"
    )

    # ============================================================================
    # Symbol Table Errors (E1000-E1999)
    # ============================================================================
    SYMBOL_NOT_FOUND = ErrorDef("E1001", "symbol", "Symbol '{name}' not found")
    DUPLICATE_SYMBOL_DECL = ErrorDef(
        "E1002", "symbol", "Symbol '{name}' already declared"
    )
    SYMBOL_REDECLARED = ErrorDef("E1003", "symbol", "Symbol '{name}' redeclared")
    INVALID_SYMBOL_NAME = ErrorDef("E1004", "symbol", "Invalid symbol name: {name}")
    PRIVATE_SYMBOL_ACCESS = ErrorDef(
        "E1005", "symbol", "Cannot access private symbol '{name}' from this context"
    )
    PROTECTED_SYMBOL_ACCESS = ErrorDef(
        "E1006", "symbol", "Cannot access protected symbol '{name}' from this context"
    )

    # ============================================================================
    # Type System Errors (E2000-E2999)
    # ============================================================================
    TYPE_MISMATCH = ErrorDef("E2001", "type", "Type mismatch{details_suffix}")
    TYPE_ASSIGNMENT_ERROR = ErrorDef(
        "E2002", "type", "Cannot assign {right_type} to {left_type}"
    )
    TYPE_NOT_FOUND = ErrorDef("E2003", "type", "Type '{type_name}' not found")
    INCOMPATIBLE_TYPES = ErrorDef(
        "E2004", "type", "Incompatible types: {type1} and {type2}"
    )
    MISSING_TYPE_ANNOTATION = ErrorDef(
        "E2005", "type", "Missing type annotation for {name}"
    )
    INVALID_TYPE_ARGUMENT = ErrorDef("E2006", "type", "Invalid type argument: {arg}")
    GENERIC_TYPE_ERROR = ErrorDef("E2007", "type", "Generic type error: {details}")
    TYPE_INFERENCE_FAILED = ErrorDef(
        "E2008", "type", "Type inference failed for {expr}"
    )
    TYPE_ASSIGNMENT_TO_PARAMETER = ErrorDef(
        "E2009",
        "type",
        "Cannot assign {arg_type} to parameter '{param_name}' of type {param_type}",
    )
    MISSING_FUNCTION_PARAMETERS = ErrorDef(
        "E2010",
        "type",
        "Not all required parameters were provided in the function call: {param_names}",
    )

    # ============================================================================
    # Semantic Analysis Errors (E3000-E3999)
    # ============================================================================
    INVALID_TARGET_CONTEXT = ErrorDef(
        "E3001", "semantic", "Invalid target for context update: {target}"
    )
    MISSING_ATTRIBUTE = ErrorDef(
        "E3002", "semantic", "Object has no attribute '{attr}'"
    )
    INVALID_OPERATION = ErrorDef("E3003", "semantic", "Invalid operation: {operation}")
    INVALID_IMPORT = ErrorDef("E3004", "semantic", "Invalid import: {details}")
    MODULE_NOT_FOUND = ErrorDef("E3005", "semantic", "Module '{module}' not found")
    CIRCULAR_IMPORT = ErrorDef(
        "E3006", "semantic", "Circular import detected: {module}"
    )
    INVALID_STRING_IMPORT = ErrorDef(
        "E3007",
        "semantic",
        'String literal imports (e.g., from "{module}") are only supported in client (cl) imports',
    )
    MISSING_MODULE_IN_PROGRAM = ErrorDef(
        "E3008",
        "semantic",
        "Module {module} not found in the program. Something went wrong.",
    )
    INVALID_ASSIGNMENT_TARGET = ErrorDef(
        "E3009", "semantic", "Invalid assignment target: {target}"
    )
    INVALID_NAMED_TARGET = ErrorDef("E3010", "semantic", "Named target not valid")
    INVALID_FOR_LOOP_TARGET = ErrorDef(
        "E3011", "semantic", "For loop assignment target not valid"
    )
    INVALID_FOR_EXPR_TARGET = ErrorDef(
        "E3012", "semantic", "For expr as target not valid"
    )
    EMPTY_MODULE_PATH = ErrorDef("E3013", "semantic", "Module path is empty.")
    LENGTH_MISMATCH_ASYNC_FOR = ErrorDef(
        "E3014", "semantic", "Length mismatch in async for body"
    )
    LENGTH_MISMATCH_IMPORT = ErrorDef(
        "E3015", "semantic", "Length mismatch in import names"
    )
    ABSTRACT_ABILITY_HAS_BODY = ErrorDef(
        "E3016", "semantic", "Abstract ability {ability_name} should not have a body."
    )
    ABSTRACT_ABILITY_HAS_DEFINITION = ErrorDef(
        "E3017",
        "semantic",
        "Abstract ability {ability_name} should not have a definition.",
    )
    PARAMETER_COUNT_MISMATCH = ErrorDef(
        "E3018", "semantic", "Parameter count mismatch for ability {ability_name}."
    )
    NON_DEFAULT_AFTER_DEFAULT = ErrorDef(
        "E3019",
        "semantic",
        "Non default attribute '{attr_name}' follows default attribute",
    )
    MISSING_POSTINIT_METHOD = ErrorDef(
        "E3020",
        "semantic",
        'Missing "postinit" method required by un initialized attribute(s).',
    )
    ARCHETYPE_NO_BODY = ErrorDef(
        "E3021", "semantic", "Archetype has no body. Perhaps an impl must be imported."
    )
    ABILITY_NO_BODY = ErrorDef(
        "E3022", "semantic", "Ability has no body. Perhaps an impl must be imported."
    )
    INVALID_PIPE_TARGET = ErrorDef("E3023", "semantic", "Invalid pipe target.")
    UNSUPPORTED_BINARY_OPERATOR = ErrorDef(
        "E3024", "semantic", "Binary operator {operator} not supported in bootstrap Jac"
    )
    INVALID_ATTRIBUTE_ACCESS = ErrorDef("E3025", "semantic", "Invalid attribute access")

    # ============================================================================
    # Code Generation Errors (E4000-E4999)
    # ============================================================================
    CODEGEN_FAILED = ErrorDef("E4001", "codegen", "Code generation failed: {details}")
    BYTECODE_GEN_FAILED = ErrorDef(
        "E4002", "codegen", "Bytecode generation failed for {module}"
    )
    AST_NOT_FOUND = ErrorDef(
        "E4003", "codegen", "Unable to find AST for module {module}"
    )
    UNSUPPORTED_FEATURE = ErrorDef(
        "E4004", "codegen", "Feature '{feature}' is not yet supported"
    )
    FORMATTING_ERROR = ErrorDef("E4005", "codegen", "Error during formatting: {error}")

    # ============================================================================
    # Internal Compiler Errors (E5000-E5999)
    # ============================================================================
    ICE_UNEXPECTED_NODE = ErrorDef(
        "E5001",
        "ice",
        "Internal Compiler Error: Unexpected node type '{node_type}' in pass '{pass_name}'",
    )
    ICE_MISSING_SYMBOL_INFO = ErrorDef(
        "E5002",
        "ice",
        "Internal Compiler Error: Missing symbol information for '{name}'",
    )
    ICE_PASS_ERROR = ErrorDef(
        "E5003", "ice", "Internal Compiler Error: Pass {pass_name} - {message}"
    )
    ICE_UNKNOWN_ERROR = ErrorDef(
        "E5004", "ice", "Internal Compiler Error: Something went horribly wrong!"
    )

    # ============================================================================
    # Warnings (W0000-W0999)
    # ============================================================================
    UNUSED_VARIABLE = ErrorDef(
        "W0001", "warning", "Variable '{name}' is declared but never used"
    )
    UNUSED_IMPORT = ErrorDef("W0002", "warning", "Import '{module}' is unused")
    POTENTIAL_NULL_DEREF = ErrorDef(
        "W0003", "warning", "Potential null dereference of '{variable}'"
    )
    DEPRECATED_FEATURE = ErrorDef(
        "W0004", "warning", "Feature '{feature}' is deprecated: {suggestion}"
    )
    ATTRIBUTE_ERROR = ErrorDef(
        "W0005", "warning", "Attribute error when accessing node attributes: {error}"
    )
    EXPERIMENTAL_FEATURE = ErrorDef(
        "W0006", "warning", "{feature} is Experimental, Please use with caution."
    )
    MODULE_NOT_FOUND_WARNING = ErrorDef(
        "W0007", "warning", "Module '{module}' not found"
    )

    # ============================================================================
    # Properties and Methods
    # ============================================================================

    @property
    def code(self) -> str:
        """Get the error code string (e.g., 'E2002')."""
        return self.value.code

    @property
    def defn(self) -> ErrorDef:
        """Get the error definition."""
        return self.value

    @property
    def category(self) -> str:
        """Get the error category."""
        return self.value.category

    def format_message(self, **kwargs: object) -> str:
        """Format the error message with provided parameters.

        This is the main method to use when creating error messages.
        It validates parameters and formats the template.

        Args:
            **kwargs: Parameters to format into the message template

        Returns:
            Formatted error message string

        Raises:
            ValueError: If required parameters are missing
        """
        return self.defn.format(**kwargs)

    def is_warning(self) -> bool:
        """Check if this error code represents a warning."""
        return self.code.startswith("W")

    def is_error(self) -> bool:
        """Check if this error code represents an error."""
        return self.code.startswith("E")

    def __str__(self) -> str:
        """Return the error code as a string."""
        return self.code
