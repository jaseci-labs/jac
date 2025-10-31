"""Type-safe parameter definitions for error codes.

This module provides TypedDict definitions for each error code's parameters,
enabling compile-time type checking and IDE autocomplete support.
"""

from typing import TypedDict


# Type-safe parameter definitions for each error code
class SyntaxErrorParams(TypedDict, total=False):
    """Parameters for SYNTAX_ERROR."""

    message_suffix: str


class UnexpectedTokenParams(TypedDict):
    """Parameters for UNEXPECTED_TOKEN."""

    token: str


class InvalidCharacterParams(TypedDict):
    """Parameters for INVALID_CHARACTER."""

    char: str


class MissingTokenParams(TypedDict):
    """Parameters for MISSING_TOKEN."""

    token: str


class InvalidAsyncArchetypeParams(TypedDict):
    """Parameters for INVALID_ASYNC_ARCHETYPE."""

    arch_type: str


class InvalidFunctionParametersParams(TypedDict):
    """Parameters for INVALID_FUNCTION_PARAMETERS."""

    details: str


class InvalidFunctionParametersOrderParams(TypedDict):
    """Parameters for INVALID_FUNCTION_PARAMETERS_ORDER."""

    details: str


# Symbol Table Error Parameters
class SymbolNotFoundParams(TypedDict):
    """Parameters for SYMBOL_NOT_FOUND."""

    name: str


class DuplicateSymbolDeclParams(TypedDict):
    """Parameters for DUPLICATE_SYMBOL_DECL."""

    name: str


class SymbolRedeclaredParams(TypedDict):
    """Parameters for SYMBOL_REDECLARED."""

    name: str


class InvalidSymbolNameParams(TypedDict):
    """Parameters for INVALID_SYMBOL_NAME."""

    name: str


class PrivateSymbolAccessParams(TypedDict):
    """Parameters for PRIVATE_SYMBOL_ACCESS."""

    name: str


class ProtectedSymbolAccessParams(TypedDict):
    """Parameters for PROTECTED_SYMBOL_ACCESS."""

    name: str


# Type System Error Parameters
class TypeMismatchParams(TypedDict, total=False):
    """Parameters for TYPE_MISMATCH."""

    details_suffix: str


class TypeAssignmentErrorParams(TypedDict):
    """Parameters for TYPE_ASSIGNMENT_ERROR."""

    right_type: str
    left_type: str


class TypeNotFoundParams(TypedDict):
    """Parameters for TYPE_NOT_FOUND."""

    type_name: str


class IncompatibleTypesParams(TypedDict):
    """Parameters for INCOMPATIBLE_TYPES."""

    type1: str
    type2: str


class MissingTypeAnnotationParams(TypedDict):
    """Parameters for MISSING_TYPE_ANNOTATION."""

    name: str


class InvalidTypeArgumentParams(TypedDict):
    """Parameters for INVALID_TYPE_ARGUMENT."""

    arg: str


class GenericTypeErrorParams(TypedDict):
    """Parameters for GENERIC_TYPE_ERROR."""

    details: str


class TypeInferenceFailedParams(TypedDict):
    """Parameters for TYPE_INFERENCE_FAILED."""

    expr: str


class TypeAssignmentToParameterParams(TypedDict):
    """Parameters for TYPE_ASSIGNMENT_TO_PARAMETER."""

    arg_type: str
    param_name: str
    param_type: str


class MissingFunctionParametersParams(TypedDict):
    """Parameters for MISSING_FUNCTION_PARAMETERS."""

    param_names: str


# Semantic Analysis Error Parameters
class InvalidTargetContextParams(TypedDict):
    """Parameters for INVALID_TARGET_CONTEXT."""

    target: str


class MissingAttributeParams(TypedDict):
    """Parameters for MISSING_ATTRIBUTE."""

    attr: str


class InvalidOperationParams(TypedDict):
    """Parameters for INVALID_OPERATION."""

    operation: str


class InvalidImportParams(TypedDict):
    """Parameters for INVALID_IMPORT."""

    details: str


class ModuleNotFoundParams(TypedDict):
    """Parameters for MODULE_NOT_FOUND."""

    module: str


class CircularImportParams(TypedDict):
    """Parameters for CIRCULAR_IMPORT."""

    module: str


class InvalidStringImportParams(TypedDict):
    """Parameters for INVALID_STRING_IMPORT."""

    module: str


class MissingModuleInProgramParams(TypedDict):
    """Parameters for MISSING_MODULE_IN_PROGRAM."""

    module: str


class InvalidAssignmentTargetParams(TypedDict):
    """Parameters for INVALID_ASSIGNMENT_TARGET."""

    target: str


class NonDefaultAfterDefaultParams(TypedDict):
    """Parameters for NON_DEFAULT_AFTER_DEFAULT."""

    attr_name: str


class AbstractAbilityHasBodyParams(TypedDict):
    """Parameters for ABSTRACT_ABILITY_HAS_BODY."""

    ability_name: str


class AbstractAbilityHasDefinitionParams(TypedDict):
    """Parameters for ABSTRACT_ABILITY_HAS_DEFINITION."""

    ability_name: str


class ParameterCountMismatchParams(TypedDict):
    """Parameters for PARAMETER_COUNT_MISMATCH."""

    ability_name: str


# Code Generation Error Parameters
class CodegenFailedParams(TypedDict):
    """Parameters for CODEGEN_FAILED."""

    details: str


class BytecodeGenFailedParams(TypedDict):
    """Parameters for BYTECODE_GEN_FAILED."""

    module: str


class AstNotFoundParams(TypedDict):
    """Parameters for AST_NOT_FOUND."""

    module: str


class UnsupportedFeatureParams(TypedDict):
    """Parameters for UNSUPPORTED_FEATURE."""

    feature: str


class FormattingErrorParams(TypedDict):
    """Parameters for FORMATTING_ERROR."""

    error: str


# Internal Compiler Error Parameters
class IceUnexpectedNodeParams(TypedDict):
    """Parameters for ICE_UNEXPECTED_NODE."""

    node_type: str
    pass_name: str


class IceMissingSymbolInfoParams(TypedDict):
    """Parameters for ICE_MISSING_SYMBOL_INFO."""

    name: str


class IcePassErrorParams(TypedDict):
    """Parameters for ICE_PASS_ERROR."""

    pass_name: str
    message: str


# Warning Parameters
class UnusedVariableParams(TypedDict):
    """Parameters for UNUSED_VARIABLE."""

    name: str


class UnusedImportParams(TypedDict):
    """Parameters for UNUSED_IMPORT."""

    module: str


class PotentialNullDerefParams(TypedDict):
    """Parameters for POTENTIAL_NULL_DEREF."""

    variable: str


class DeprecatedFeatureParams(TypedDict):
    """Parameters for DEPRECATED_FEATURE."""

    feature: str
    suggestion: str


class AttributeErrorParams(TypedDict):
    """Parameters for ATTRIBUTE_ERROR."""

    error: str


class ExperimentalFeatureParams(TypedDict):
    """Parameters for EXPERIMENTAL_FEATURE."""

    feature: str


class ModuleNotFoundWarningParams(TypedDict):
    """Parameters for MODULE_NOT_FOUND_WARNING."""

    module: str


class UnsupportedBinaryOperatorParams(TypedDict):
    """Parameters for UNSUPPORTED_BINARY_OPERATOR."""

    operator: str
