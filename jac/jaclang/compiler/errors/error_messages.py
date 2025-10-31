"""Centralized error message templates for Jac compiler."""

from typing import Dict, Literal, overload

from jaclang.compiler.errors.error_codes import JacErrorCode
from jaclang.compiler.errors.error_params import (
    AbstractAbilityHasBodyParams,
    AbstractAbilityHasDefinitionParams,
    AstNotFoundParams,
    AttributeErrorParams,
    BytecodeGenFailedParams,
    CircularImportParams,
    CodegenFailedParams,
    DeprecatedFeatureParams,
    DuplicateSymbolDeclParams,
    ExperimentalFeatureParams,
    FormattingErrorParams,
    GenericTypeErrorParams,
    IceMissingSymbolInfoParams,
    IcePassErrorParams,
    IceUnexpectedNodeParams,
    IncompatibleTypesParams,
    InvalidAssignmentTargetParams,
    InvalidAsyncArchetypeParams,
    InvalidCharacterParams,
    InvalidFunctionParametersOrderParams,
    InvalidFunctionParametersParams,
    InvalidImportParams,
    InvalidOperationParams,
    InvalidStringImportParams,
    InvalidSymbolNameParams,
    InvalidTargetContextParams,
    InvalidTypeArgumentParams,
    MissingAttributeParams,
    MissingFunctionParametersParams,
    MissingModuleInProgramParams,
    MissingTokenParams,
    MissingTypeAnnotationParams,
    ModuleNotFoundParams,
    ModuleNotFoundWarningParams,
    NonDefaultAfterDefaultParams,
    ParameterCountMismatchParams,
    PotentialNullDerefParams,
    PrivateSymbolAccessParams,
    ProtectedSymbolAccessParams,
    SymbolNotFoundParams,
    SymbolRedeclaredParams,
    SyntaxErrorParams,
    TypeAssignmentErrorParams,
    TypeAssignmentToParameterParams,
    TypeInferenceFailedParams,
    TypeMismatchParams,
    TypeNotFoundParams,
    UnexpectedTokenParams,
    UnsupportedBinaryOperatorParams,
    UnsupportedFeatureParams,
    UnusedImportParams,
    UnusedVariableParams,
)

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


# Type-safe overloads for error codes with parameters
@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.SYNTAX_ERROR],  # type: ignore[valid-type]
    **kwargs: SyntaxErrorParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.UNEXPECTED_TOKEN],  # type: ignore[valid-type]
    **kwargs: UnexpectedTokenParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.INVALID_CHARACTER],  # type: ignore[valid-type]
    **kwargs: InvalidCharacterParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.MISSING_TOKEN],  # type: ignore[valid-type]
    **kwargs: MissingTokenParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.INVALID_ASYNC_ARCHETYPE],  # type: ignore[valid-type]
    **kwargs: InvalidAsyncArchetypeParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.INVALID_FUNCTION_PARAMETERS],  # type: ignore[valid-type]
    **kwargs: InvalidFunctionParametersParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.INVALID_FUNCTION_PARAMETERS_ORDER],  # type: ignore[valid-type]
    **kwargs: InvalidFunctionParametersOrderParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.SYMBOL_NOT_FOUND],  # type: ignore[valid-type]
    **kwargs: SymbolNotFoundParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.DUPLICATE_SYMBOL_DECL],  # type: ignore[valid-type]
    **kwargs: DuplicateSymbolDeclParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.SYMBOL_REDECLARED],  # type: ignore[valid-type]
    **kwargs: SymbolRedeclaredParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.INVALID_SYMBOL_NAME],  # type: ignore[valid-type]
    **kwargs: InvalidSymbolNameParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.PRIVATE_SYMBOL_ACCESS],  # type: ignore[valid-type]
    **kwargs: PrivateSymbolAccessParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.PROTECTED_SYMBOL_ACCESS],  # type: ignore[valid-type]
    **kwargs: ProtectedSymbolAccessParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.TYPE_MISMATCH],  # type: ignore[valid-type]
    **kwargs: TypeMismatchParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.TYPE_ASSIGNMENT_ERROR],  # type: ignore[valid-type]
    **kwargs: TypeAssignmentErrorParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.TYPE_NOT_FOUND],  # type: ignore[valid-type]
    **kwargs: TypeNotFoundParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.INCOMPATIBLE_TYPES],  # type: ignore[valid-type]
    **kwargs: IncompatibleTypesParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.MISSING_TYPE_ANNOTATION],  # type: ignore[valid-type]
    **kwargs: MissingTypeAnnotationParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.INVALID_TYPE_ARGUMENT],  # type: ignore[valid-type]
    **kwargs: InvalidTypeArgumentParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.GENERIC_TYPE_ERROR],  # type: ignore[valid-type]
    **kwargs: GenericTypeErrorParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.TYPE_INFERENCE_FAILED],  # type: ignore[valid-type]
    **kwargs: TypeInferenceFailedParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.TYPE_ASSIGNMENT_TO_PARAMETER],  # type: ignore[valid-type]
    **kwargs: TypeAssignmentToParameterParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.MISSING_FUNCTION_PARAMETERS],  # type: ignore[valid-type]
    **kwargs: MissingFunctionParametersParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.INVALID_TARGET_CONTEXT],  # type: ignore[valid-type]
    **kwargs: InvalidTargetContextParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.MISSING_ATTRIBUTE],  # type: ignore[valid-type]
    **kwargs: MissingAttributeParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.INVALID_OPERATION],  # type: ignore[valid-type]
    **kwargs: InvalidOperationParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.INVALID_IMPORT],  # type: ignore[valid-type]
    **kwargs: InvalidImportParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.MODULE_NOT_FOUND],  # type: ignore[valid-type]
    **kwargs: ModuleNotFoundParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.CIRCULAR_IMPORT],  # type: ignore[valid-type]
    **kwargs: CircularImportParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.INVALID_STRING_IMPORT],  # type: ignore[valid-type]
    **kwargs: InvalidStringImportParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.MISSING_MODULE_IN_PROGRAM],  # type: ignore[valid-type]
    **kwargs: MissingModuleInProgramParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.INVALID_ASSIGNMENT_TARGET],  # type: ignore[valid-type]
    **kwargs: InvalidAssignmentTargetParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.NON_DEFAULT_AFTER_DEFAULT],  # type: ignore[valid-type]
    **kwargs: NonDefaultAfterDefaultParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.ABSTRACT_ABILITY_HAS_BODY],  # type: ignore[valid-type]
    **kwargs: AbstractAbilityHasBodyParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.ABSTRACT_ABILITY_HAS_DEFINITION],  # type: ignore[valid-type]
    **kwargs: AbstractAbilityHasDefinitionParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.PARAMETER_COUNT_MISMATCH],  # type: ignore[valid-type]
    **kwargs: ParameterCountMismatchParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.CODEGEN_FAILED],  # type: ignore[valid-type]
    **kwargs: CodegenFailedParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.BYTECODE_GEN_FAILED],  # type: ignore[valid-type]
    **kwargs: BytecodeGenFailedParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.AST_NOT_FOUND],  # type: ignore[valid-type]
    **kwargs: AstNotFoundParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.UNSUPPORTED_FEATURE],  # type: ignore[valid-type]
    **kwargs: UnsupportedFeatureParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.FORMATTING_ERROR],  # type: ignore[valid-type]
    **kwargs: FormattingErrorParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.ICE_UNEXPECTED_NODE],  # type: ignore[valid-type]
    **kwargs: IceUnexpectedNodeParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.ICE_MISSING_SYMBOL_INFO],  # type: ignore[valid-type]
    **kwargs: IceMissingSymbolInfoParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.ICE_PASS_ERROR],  # type: ignore[valid-type]
    **kwargs: IcePassErrorParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.UNUSED_VARIABLE],  # type: ignore[valid-type]
    **kwargs: UnusedVariableParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.UNUSED_IMPORT],  # type: ignore[valid-type]
    **kwargs: UnusedImportParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.POTENTIAL_NULL_DEREF],  # type: ignore[valid-type]
    **kwargs: PotentialNullDerefParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.DEPRECATED_FEATURE],  # type: ignore[valid-type]
    **kwargs: DeprecatedFeatureParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.ATTRIBUTE_ERROR],  # type: ignore[valid-type]
    **kwargs: AttributeErrorParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.EXPERIMENTAL_FEATURE],  # type: ignore[valid-type]
    **kwargs: ExperimentalFeatureParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.MODULE_NOT_FOUND_WARNING],  # type: ignore[valid-type]
    **kwargs: ModuleNotFoundWarningParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[JacErrorCode.UNSUPPORTED_BINARY_OPERATOR],  # type: ignore[valid-type]
    **kwargs: UnsupportedBinaryOperatorParams,
) -> str: ...  # type: ignore[misc,overload-cannot-match]


# Overloads for error codes with no parameters
@overload  # type: ignore[overload-cannot-match]
def get_error_message(  # noqa: E704
    code: Literal[
        JacErrorCode.UNEXPECTED_EOF,
        JacErrorCode.MISSING_COLON,
        JacErrorCode.MISSING_SEMICOLON,
        JacErrorCode.MISSING_CLOSING_BRACE,
        JacErrorCode.MISSING_CLOSING_PAREN,
        JacErrorCode.MISSING_CLOSING_BRACKET,
        JacErrorCode.INVALID_INDENTATION,
        JacErrorCode.INCOMPLETE_MEMBER_ACCESS,
        JacErrorCode.INVALID_PARSE_TREE,
        JacErrorCode.INVALID_NAMED_TARGET,
        JacErrorCode.INVALID_FOR_LOOP_TARGET,
        JacErrorCode.INVALID_FOR_EXPR_TARGET,
        JacErrorCode.EMPTY_MODULE_PATH,
        JacErrorCode.LENGTH_MISMATCH_ASYNC_FOR,
        JacErrorCode.LENGTH_MISMATCH_IMPORT,
        JacErrorCode.MISSING_POSTINIT_METHOD,
        JacErrorCode.ARCHETYPE_NO_BODY,
        JacErrorCode.ABILITY_NO_BODY,
        JacErrorCode.INVALID_PIPE_TARGET,
        JacErrorCode.INVALID_ATTRIBUTE_ACCESS,
        JacErrorCode.ICE_UNKNOWN_ERROR,
    ],
) -> str: ...  # type: ignore[misc,overload-cannot-match]


def get_error_message(code: JacErrorCode, **kwargs: object) -> str:
    """Get formatted error message for an error code.

    This function provides strict type-safe overloads for each error code,
    ensuring compile-time type checking of parameters. Type checkers will
    enforce that the correct parameters are provided for each error code.

    Args:
        code: The error code (type checker validates against specific overloads)
        **kwargs: Arguments for message template formatting.
            Must match the TypedDict parameters for the specific error code.

    Returns:
        Formatted error message string

    Raises:
        KeyError: If error code has no template
        KeyError: If required template arguments are missing

    Note:
        This function uses overloads to provide strict type checking.
        Type checkers (mypy, pyright) will validate parameters at compile time.
        All error codes must be called with parameters matching their TypedDict.
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

        # Validate required parameters are provided
        if used_args:
            missing = used_args - set(filtered_kwargs.keys())
            if missing:
                return (
                    f"[{code.value}] Internal Compiler Error: Missing required argument(s) "
                    f"'{', '.join(missing)}' for error {code.name}"
                )

        return template.format(**filtered_kwargs)
    except KeyError as e:
        missing_arg = str(e).strip("'\"")
        return (
            f"[{code.value}] Internal Compiler Error: Missing argument '{missing_arg}' "
            f"for error {code.name} in template: '{template}'"
        )
