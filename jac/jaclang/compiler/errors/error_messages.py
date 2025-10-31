"""Centralized error message templates for Jac compiler."""

from typing import Dict

from jaclang.compiler.errors.error_codes import JacErrorCode

# Error message templates using Python format string syntax
# Arguments can be passed via kwargs when formatting
ERROR_MESSAGE_TEMPLATES: Dict[JacErrorCode, str] = {
    # General/Syntax Errors
    JacErrorCode.SYNTAX_ERROR: "Syntax error{message_suffix}",
    JacErrorCode.UNEXPECTED_TOKEN: "Unexpected token: {token}",
    JacErrorCode.UNEXPECTED_EOF: "Unexpected end of file",
    JacErrorCode.INVALID_CHARACTER: "Invalid character: {char}",
    JacErrorCode.MISSING_COLON: "Missing colon",
    JacErrorCode.MISSING_SEMICOLON: "Missing semicolon",
    JacErrorCode.MISSING_CLOSING_BRACE: "Missing closing brace '}}'",
    JacErrorCode.MISSING_CLOSING_PAREN: "Missing closing parenthesis ')'",
    JacErrorCode.MISSING_CLOSING_BRACKET: "Missing closing bracket ']'",
    JacErrorCode.INVALID_INDENTATION: "Invalid indentation",
    JacErrorCode.MISSING_TOKEN: "Missing {token}",
    JacErrorCode.INCOMPLETE_MEMBER_ACCESS: "Incomplete member access",
    JacErrorCode.INVALID_PARSE_TREE: "Internal Compiler Error, Invalid Parse Tree!",
    JacErrorCode.INVALID_ASYNC_ARCHETYPE: "Expected async archetype to be walker, but got {arch_type}",
    JacErrorCode.INVALID_FUNCTION_PARAMETERS: "Invalid syntax in function parameters: '{details}'",
    JacErrorCode.INVALID_FUNCTION_PARAMETERS_ORDER: "Invalid syntax in function parameters: '{details}'",
    # Symbol Table Errors
    JacErrorCode.SYMBOL_NOT_FOUND: "Symbol '{name}' not found",
    JacErrorCode.DUPLICATE_SYMBOL_DECL: "Symbol '{name}' already declared",
    JacErrorCode.SYMBOL_REDECLARED: "Symbol '{name}' redeclared",
    JacErrorCode.INVALID_SYMBOL_NAME: "Invalid symbol name: {name}",
    JacErrorCode.PRIVATE_SYMBOL_ACCESS: "Cannot access private symbol '{name}' from this context",
    JacErrorCode.PROTECTED_SYMBOL_ACCESS: "Cannot access protected symbol '{name}' from this context",
    # Type System Errors
    JacErrorCode.TYPE_MISMATCH: "Type mismatch{details_suffix}",
    JacErrorCode.TYPE_ASSIGNMENT_ERROR: "Cannot assign {right_type} to {left_type}",
    JacErrorCode.TYPE_NOT_FOUND: "Type '{type_name}' not found",
    JacErrorCode.INCOMPATIBLE_TYPES: "Incompatible types: {type1} and {type2}",
    JacErrorCode.MISSING_TYPE_ANNOTATION: "Missing type annotation for {name}",
    JacErrorCode.INVALID_TYPE_ARGUMENT: "Invalid type argument: {arg}",
    JacErrorCode.GENERIC_TYPE_ERROR: "Generic type error: {details}",
    JacErrorCode.TYPE_INFERENCE_FAILED: "Type inference failed for {expr}",
    JacErrorCode.TYPE_ASSIGNMENT_TO_PARAMETER: (
        "Cannot assign {arg_type} to parameter '{param_name}' of type {param_type}"
    ),
    JacErrorCode.MISSING_FUNCTION_PARAMETERS: (
        "Not all required parameters were provided in the function call: {param_names}"
    ),
    # Semantic Analysis Errors
    JacErrorCode.INVALID_TARGET_CONTEXT: "Invalid target for context update: {target}",
    JacErrorCode.MISSING_ATTRIBUTE: "Object has no attribute '{attr}'",
    JacErrorCode.INVALID_OPERATION: "Invalid operation: {operation}",
    JacErrorCode.INVALID_IMPORT: "Invalid import: {details}",
    JacErrorCode.MODULE_NOT_FOUND: "Module '{module}' not found",
    JacErrorCode.CIRCULAR_IMPORT: "Circular import detected: {module}",
    JacErrorCode.INVALID_STRING_IMPORT: (
        'String literal imports (e.g., from "{module}") '
        "are only supported in client (cl) imports"
    ),
    JacErrorCode.MISSING_MODULE_IN_PROGRAM: "Module {module} not found in the program. Something went wrong.",
    JacErrorCode.INVALID_ASSIGNMENT_TARGET: "Invalid assignment target: {target}",
    JacErrorCode.INVALID_NAMED_TARGET: "Named target not valid",
    JacErrorCode.INVALID_FOR_LOOP_TARGET: "For loop assignment target not valid",
    JacErrorCode.INVALID_FOR_EXPR_TARGET: "For expr as target not valid",
    JacErrorCode.EMPTY_MODULE_PATH: "Module path is empty.",
    JacErrorCode.LENGTH_MISMATCH_ASYNC_FOR: "Length mismatch in async for body",
    JacErrorCode.LENGTH_MISMATCH_IMPORT: "Length mismatch in import names",
    JacErrorCode.ABSTRACT_ABILITY_HAS_BODY: "Abstract ability {ability_name} should not have a body.",
    JacErrorCode.ABSTRACT_ABILITY_HAS_DEFINITION: "Abstract ability {ability_name} should not have a definition.",
    JacErrorCode.PARAMETER_COUNT_MISMATCH: "Parameter count mismatch for ability {ability_name}.",
    JacErrorCode.NON_DEFAULT_AFTER_DEFAULT: "Non default attribute '{attr_name}' follows default attribute",
    JacErrorCode.MISSING_POSTINIT_METHOD: 'Missing "postinit" method required by un initialized attribute(s).',
    JacErrorCode.ARCHETYPE_NO_BODY: "Archetype has no body. Perhaps an impl must be imported.",
    JacErrorCode.ABILITY_NO_BODY: "Ability has no body. Perhaps an impl must be imported.",
    JacErrorCode.INVALID_PIPE_TARGET: "Invalid pipe target.",
    JacErrorCode.UNSUPPORTED_BINARY_OPERATOR: "Binary operator {operator} not supported in bootstrap Jac",
    JacErrorCode.INVALID_ATTRIBUTE_ACCESS: "Invalid attribute access",
    # Code Generation Errors
    JacErrorCode.CODEGEN_FAILED: "Code generation failed: {details}",
    JacErrorCode.BYTECODE_GEN_FAILED: "Bytecode generation failed for {module}",
    JacErrorCode.AST_NOT_FOUND: "Unable to find AST for module {module}",
    JacErrorCode.UNSUPPORTED_FEATURE: "Feature '{feature}' is not yet supported",
    JacErrorCode.FORMATTING_ERROR: "Error during formatting: {error}",
    # Internal Compiler Errors
    JacErrorCode.ICE_UNEXPECTED_NODE: (
        "Internal Compiler Error: Unexpected node type '{node_type}' "
        "in pass '{pass_name}'"
    ),
    JacErrorCode.ICE_MISSING_SYMBOL_INFO: "Internal Compiler Error: Missing symbol information for '{name}'",
    JacErrorCode.ICE_PASS_ERROR: "Internal Compiler Error: Pass {pass_name} - {message}",
    JacErrorCode.ICE_UNKNOWN_ERROR: "Internal Compiler Error: Something went horribly wrong!",
    # Warnings
    JacErrorCode.UNUSED_VARIABLE: "Variable '{name}' is declared but never used",
    JacErrorCode.UNUSED_IMPORT: "Import '{module}' is unused",
    JacErrorCode.POTENTIAL_NULL_DEREF: "Potential null dereference of '{variable}'",
    JacErrorCode.DEPRECATED_FEATURE: "Feature '{feature}' is deprecated: {suggestion}",
    JacErrorCode.ATTRIBUTE_ERROR: "Attribute error when accessing node attributes: {error}",
    JacErrorCode.EXPERIMENTAL_FEATURE: "{feature} is Experimental, Please use with caution.",
    JacErrorCode.MODULE_NOT_FOUND_WARNING: "Module '{module}' not found",
}


def get_error_message(code: JacErrorCode, **kwargs: object) -> str:
    """Get formatted error message for an error code.

    Args:
        code: The error code
        **kwargs: Arguments for message template formatting

    Returns:
        Formatted error message string

    Raises:
        KeyError: If error code has no template
        KeyError: If required template arguments are missing
    """
    template = ERROR_MESSAGE_TEMPLATES.get(code)
    if not template:
        return f"[{code.value}] No message template defined for {code.name}"

    try:
        # Filter kwargs to only include those that are actually used in the template
        # This prevents KeyError when extra kwargs are passed
        import string

        formatter = string.Formatter()
        used_args = {name for _, name, _, _ in formatter.parse(template) if name}
        filtered_kwargs = {k: v for k, v in kwargs.items() if k in used_args}
        return template.format(**filtered_kwargs)
    except KeyError as e:
        missing_arg = str(e).strip("'\"")
        return (
            f"[{code.value}] Internal Compiler Error: Missing argument '{missing_arg}' "
            f"for error {code.name} in template: '{template}'"
        )
