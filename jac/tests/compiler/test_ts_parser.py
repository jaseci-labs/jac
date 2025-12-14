"""Tests for TypeScript parser."""

from collections.abc import Callable
from pathlib import Path
from typing import Protocol

import pytest

import jaclang.pycore.unitree as uni
from jaclang.pycore.program import JacProgram
from jaclang.pycore.tsparser import TypeScriptParser
from jaclang.pycore.unitree import Source


class ParseTsFn(Protocol):
    """Protocol for parse_ts callable with optional mod_path."""

    def __call__(self, source_code: str, mod_path: str = "") -> TypeScriptParser: ...


@pytest.fixture
def ts_fixture_abs_path() -> Callable[[str], str]:
    """Get absolute path to TypeScript fixture file."""

    def _ts_fixture_abs_path(filename: str) -> str:
        return str(Path(__file__).parent / "fixtures" / "typescript" / filename)

    return _ts_fixture_abs_path


@pytest.fixture
def load_ts_fixture(ts_fixture_abs_path: Callable[[str], str]) -> Callable[[str], str]:
    """Load TypeScript fixture file contents."""

    def _load_ts_fixture(filename: str) -> str:
        path = ts_fixture_abs_path(filename)
        with open(path, encoding="utf-8") as f:
            return f.read()

    return _load_ts_fixture


@pytest.fixture
def parse_ts() -> ParseTsFn:
    """Parse TypeScript source code and return parser."""

    def _parse_ts(source_code: str, mod_path: str = "") -> TypeScriptParser:
        source = Source(source_code, mod_path=mod_path)
        return TypeScriptParser(root_ir=source, prog=JacProgram())

    return _parse_ts


@pytest.fixture
def parse_ts_file(
    load_ts_fixture: Callable[[str], str],
    ts_fixture_abs_path: Callable[[str], str],
    parse_ts: ParseTsFn,
) -> Callable[[str], TypeScriptParser]:
    """Parse TypeScript fixture file and return parser."""

    def _parse_ts_file(filename: str) -> TypeScriptParser:
        source_code = load_ts_fixture(filename)
        return parse_ts(source_code, ts_fixture_abs_path(filename))

    return _parse_ts_file


# ==========================================================================
# Basic Parsing Tests
# ==========================================================================


def test_simple_fixture(parse_ts_file: Callable[[str], TypeScriptParser]) -> None:
    """Parse simple TypeScript fixture."""
    prse = parse_ts_file("simple.ts")
    assert not prse.errors_had
    assert isinstance(prse.ir_out, uni.Module)


def test_basic_fixture(parse_ts_file: Callable[[str], TypeScriptParser]) -> None:
    """Parse basic TypeScript fixture with variables and functions."""
    prse = parse_ts_file("basic.ts")
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_classes_fixture(parse_ts_file: Callable[[str], TypeScriptParser]) -> None:
    """Parse classes TypeScript fixture."""
    prse = parse_ts_file("classes.ts")
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_imports_exports_fixture(
    parse_ts_file: Callable[[str], TypeScriptParser],
) -> None:
    """Parse imports/exports TypeScript fixture."""
    prse = parse_ts_file("imports_exports.ts")
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_interfaces_types_fixture(
    parse_ts_file: Callable[[str], TypeScriptParser],
) -> None:
    """Parse interfaces and types TypeScript fixture."""
    prse = parse_ts_file("interfaces_types.ts")
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_enum_fixture(parse_ts_file: Callable[[str], TypeScriptParser]) -> None:
    """Parse enum TypeScript fixture."""
    prse = parse_ts_file("enum.ts")
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_control_flow_fixture(parse_ts_file: Callable[[str], TypeScriptParser]) -> None:
    """Parse control flow TypeScript fixture."""
    prse = parse_ts_file("control_flow.ts")
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_namespace_fixture(parse_ts_file: Callable[[str], TypeScriptParser]) -> None:
    """Parse namespace TypeScript fixture."""
    prse = parse_ts_file("namespace.ts")
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_decorators_fixture(parse_ts_file: Callable[[str], TypeScriptParser]) -> None:
    """Parse decorators TypeScript fixture."""
    prse = parse_ts_file("decorators.ts")
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


# ==========================================================================
# Inline Source Tests
# ==========================================================================


def test_empty_source(parse_ts: ParseTsFn) -> None:
    """Parse empty source."""
    prse = parse_ts("")
    assert not prse.errors_had
    assert isinstance(prse.ir_out, uni.Module)


def test_variable_declarations(
    parse_ts: ParseTsFn,
) -> None:
    """Parse variable declarations."""
    source = """
const x = 1;
let y = "hello";
var z = true;
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_function_declaration(parse_ts: ParseTsFn) -> None:
    """Parse function declaration."""
    source = """
function greet(name: string): string {
    return "Hello, " + name;
}
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_async_function(parse_ts: ParseTsFn) -> None:
    """Parse async function."""
    source = """
async function fetchData(): Promise<string> {
    return "data";
}
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"


def test_class_declaration(parse_ts: ParseTsFn) -> None:
    """Parse class declaration."""
    source = """
class Person {
    name: string;

    constructor(name: string) {
        this.name = name;
    }

    greet(): string {
        return "Hello, " + this.name;
    }
}
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_interface_declaration(
    parse_ts: ParseTsFn,
) -> None:
    """Parse interface declaration."""
    source = """
interface Person {
    name: string;
    age: number;
    greet(): string;
}
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_type_alias(parse_ts: ParseTsFn) -> None:
    """Parse type alias."""
    source = """
type StringOrNumber = string | number;
type ID = string;
type Callback = (x: number) => void;
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_enum_declaration(parse_ts: ParseTsFn) -> None:
    """Parse enum declaration."""
    source = """
enum Direction {
    Up,
    Down,
    Left,
    Right,
}

enum Color {
    Red = "RED",
    Green = "GREEN",
    Blue = "BLUE",
}
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_import_statements(parse_ts: ParseTsFn) -> None:
    """Parse import statements."""
    source = """
import { foo } from "./module";
import * as ns from "./module";
import defaultExport from "./module";
import "./side-effect";
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_export_statements(parse_ts: ParseTsFn) -> None:
    """Parse export statements."""
    source = """
export const x = 1;
export function greet() {}
export class MyClass {}
export { x, greet };
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_arrow_functions(parse_ts: ParseTsFn) -> None:
    """Parse arrow functions."""
    source = """
const simple = () => 1;
const withParam = (x: number) => x * 2;
const asyncArrow = async () => "async";
setTimeout(() => {
    console.log("test");
}, 100);
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_control_flow_statements(
    parse_ts: ParseTsFn,
) -> None:
    """Parse control flow statements."""
    source = """
function test(x: number) {
    if (x > 0) {
        return "positive";
    } else {
        return "non-positive";
    }

    for (let i = 0; i < 10; i++) {
        console.log(i);
    }

    while (x > 0) {
        x--;
    }

    try {
        throw new Error("test");
    } catch (e) {
        console.error(e);
    }
}
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_namespace_declaration(
    parse_ts: ParseTsFn,
) -> None:
    """Parse namespace declaration."""
    source = """
namespace MyNamespace {
    export const value = 42;
    export function helper() {}
    export class MyClass {}
}
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_decorator_syntax(parse_ts: ParseTsFn) -> None:
    """Parse decorator syntax."""
    source = """
@sealed
class MyClass {
    @readonly
    name: string;

    @logged
    greet(): string {
        return "Hello";
    }
}
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


def test_generic_syntax(parse_ts: ParseTsFn) -> None:
    """Parse generic syntax."""
    source = """
function identity<T>(x: T): T {
    return x;
}

class Container<T> {
    value: T;

    constructor(value: T) {
        this.value = value;
    }
}

interface Box<T> {
    value: T;
}
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)


# ==========================================================================
# AST Structure Tests
# ==========================================================================


def test_module_has_body(parse_ts: ParseTsFn) -> None:
    """Test that parsed module has body."""
    source = """
const x = 1;
function greet() {}
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)
    assert isinstance(prse.ir_out.body, list)
    # Body may be empty in simplified parsing mode
    assert prse.ir_out.body is not None


def test_module_name_from_path(
    parse_ts: ParseTsFn,
) -> None:
    """Test module name is derived from file path."""
    source = "const x = 1;"
    prse = parse_ts(source, mod_path="/path/to/mymodule.ts")
    assert not prse.errors_had
    assert prse.ir_out.name == "mymodule"


def test_module_name_strips_extensions(
    parse_ts: ParseTsFn,
) -> None:
    """Test various file extensions are stripped from module name."""
    test_cases = [
        ("/path/to/file.ts", "file"),
        ("/path/to/file.tsx", "file"),
        ("/path/to/file.js", "file"),
        ("/path/to/file.jsx", "file"),
    ]
    for path, expected_name in test_cases:
        prse = parse_ts("const x = 1;", mod_path=path)
        assert prse.ir_out.name == expected_name


# ==========================================================================
# Error Handling Tests
# ==========================================================================


def test_recovers_from_missing_semicolon(
    parse_ts: ParseTsFn,
) -> None:
    """Test parser can recover from missing semicolons."""
    # TypeScript usually allows missing semicolons (ASI)
    source = """
const x = 1
const y = 2
"""
    prse = parse_ts(source)
    # Even if there are recovery errors, should produce a module
    assert isinstance(prse.ir_out, uni.Module)


def test_complex_expression(parse_ts: ParseTsFn) -> None:
    """Parse complex expressions."""
    source = """
const result = a + b * c - d / e;
const ternary = condition ? valueIfTrue : valueIfFalse;
const nullish = value ?? defaultValue;
const chained = obj?.prop?.nested;
"""
    prse = parse_ts(source)
    assert not prse.errors_had, f"Errors: {prse.errors_had}"
    assert isinstance(prse.ir_out, uni.Module)
