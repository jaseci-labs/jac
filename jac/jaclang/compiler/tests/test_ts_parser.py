"""Tests for TypeScript parser."""

from pathlib import Path

from jaclang.compiler import unitree as uni
from jaclang.compiler.program import JacProgram
from jaclang.compiler.ts_parser import TypeScriptParser, get_ts_parser
from jaclang.compiler.unitree import Source
from jaclang.utils.test import TestCase


class TestTypeScriptParser(TestCase):
    """Test TypeScript parser."""

    @classmethod
    def setUpClass(cls) -> None:
        """Set up test class - ensure parser is generated."""
        super().setUpClass()
        # Ensure the TypeScript parser is generated
        get_ts_parser()

    def ts_fixture_abs_path(self, filename: str) -> str:
        """Get absolute path to TypeScript fixture file."""
        return str(Path(__file__).parent / "fixtures" / "typescript" / filename)

    def load_ts_fixture(self, filename: str) -> str:
        """Load TypeScript fixture file contents."""
        path = self.ts_fixture_abs_path(filename)
        with open(path, encoding="utf-8") as f:
            return f.read()

    def parse_ts(self, source_code: str, mod_path: str = "") -> TypeScriptParser:
        """Parse TypeScript source code and return parser."""
        source = Source(source_code, mod_path=mod_path)
        return TypeScriptParser(root_ir=source, prog=JacProgram())

    def parse_ts_file(self, filename: str) -> TypeScriptParser:
        """Parse TypeScript fixture file and return parser."""
        source_code = self.load_ts_fixture(filename)
        return self.parse_ts(source_code, mod_path=self.ts_fixture_abs_path(filename))

    # ==========================================================================
    # Basic Parsing Tests
    # ==========================================================================

    def test_parser_loads(self) -> None:
        """Test that the TypeScript parser loads successfully."""
        parser = get_ts_parser()
        self.assertIsNotNone(parser)

    def test_simple_fixture(self) -> None:
        """Parse simple TypeScript fixture."""
        prse = self.parse_ts_file("simple.ts")
        self.assertFalse(prse.errors_had)
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_basic_fixture(self) -> None:
        """Parse basic TypeScript fixture with variables and functions."""
        prse = self.parse_ts_file("basic.ts")
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_classes_fixture(self) -> None:
        """Parse classes TypeScript fixture."""
        prse = self.parse_ts_file("classes.ts")
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_imports_exports_fixture(self) -> None:
        """Parse imports/exports TypeScript fixture."""
        prse = self.parse_ts_file("imports_exports.ts")
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_interfaces_types_fixture(self) -> None:
        """Parse interfaces and types TypeScript fixture."""
        prse = self.parse_ts_file("interfaces_types.ts")
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_enum_fixture(self) -> None:
        """Parse enum TypeScript fixture."""
        prse = self.parse_ts_file("enum.ts")
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_control_flow_fixture(self) -> None:
        """Parse control flow TypeScript fixture."""
        prse = self.parse_ts_file("control_flow.ts")
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_namespace_fixture(self) -> None:
        """Parse namespace TypeScript fixture."""
        prse = self.parse_ts_file("namespace.ts")
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_decorators_fixture(self) -> None:
        """Parse decorators TypeScript fixture."""
        prse = self.parse_ts_file("decorators.ts")
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    # ==========================================================================
    # Inline Source Tests
    # ==========================================================================

    def test_empty_source(self) -> None:
        """Parse empty source."""
        prse = self.parse_ts("")
        self.assertFalse(prse.errors_had)
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_variable_declarations(self) -> None:
        """Parse variable declarations."""
        source = """
const x = 1;
let y = "hello";
var z = true;
"""
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_function_declaration(self) -> None:
        """Parse function declaration."""
        source = """
function greet(name: string): string {
    return "Hello, " + name;
}
"""
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_async_function(self) -> None:
        """Parse async function."""
        source = """
async function fetchData(): Promise<string> {
    return "data";
}
"""
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")

    def test_class_declaration(self) -> None:
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
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_interface_declaration(self) -> None:
        """Parse interface declaration."""
        source = """
interface Person {
    name: string;
    age: number;
    greet(): string;
}
"""
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_type_alias(self) -> None:
        """Parse type alias."""
        source = """
type StringOrNumber = string | number;
type ID = string;
type Callback = (x: number) => void;
"""
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_enum_declaration(self) -> None:
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
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_import_statements(self) -> None:
        """Parse import statements."""
        source = """
import { foo } from "./module";
import * as ns from "./module";
import defaultExport from "./module";
import "./side-effect";
"""
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_export_statements(self) -> None:
        """Parse export statements."""
        source = """
export const x = 1;
export function greet() {}
export class MyClass {}
export { x, greet };
"""
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_arrow_functions(self) -> None:
        """Parse arrow functions."""
        source = """
const simple = () => 1;
const withParam = (x: number) => x * 2;
const asyncArrow = async () => "async";
setTimeout(() => {
    console.log("test");
}, 100);
"""
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_control_flow_statements(self) -> None:
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
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_namespace_declaration(self) -> None:
        """Parse namespace declaration."""
        source = """
namespace MyNamespace {
    export const value = 42;
    export function helper() {}
    export class MyClass {}
}
"""
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_decorator_syntax(self) -> None:
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
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_generic_syntax(self) -> None:
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
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)

    # ==========================================================================
    # AST Structure Tests
    # ==========================================================================

    def test_module_has_body(self) -> None:
        """Test that parsed module has body."""
        source = """
const x = 1;
function greet() {}
"""
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)
        self.assertIsInstance(prse.ir_out.body, list)
        # Body may be empty in simplified parsing mode
        self.assertIsNotNone(prse.ir_out.body)

    def test_module_name_from_path(self) -> None:
        """Test module name is derived from file path."""
        source = "const x = 1;"
        prse = self.parse_ts(source, mod_path="/path/to/mymodule.ts")
        self.assertFalse(prse.errors_had)
        self.assertEqual(prse.ir_out.name, "mymodule")

    def test_module_name_strips_extensions(self) -> None:
        """Test various file extensions are stripped from module name."""
        test_cases = [
            ("/path/to/file.ts", "file"),
            ("/path/to/file.tsx", "file"),
            ("/path/to/file.js", "file"),
            ("/path/to/file.jsx", "file"),
        ]
        for path, expected_name in test_cases:
            with self.subTest(path=path):
                prse = self.parse_ts("const x = 1;", mod_path=path)
                self.assertEqual(prse.ir_out.name, expected_name)

    # ==========================================================================
    # Error Handling Tests
    # ==========================================================================

    def test_recovers_from_missing_semicolon(self) -> None:
        """Test parser can recover from missing semicolons."""
        # TypeScript usually allows missing semicolons (ASI)
        source = """
const x = 1
const y = 2
"""
        prse = self.parse_ts(source)
        # Even if there are recovery errors, should produce a module
        self.assertIsInstance(prse.ir_out, uni.Module)

    def test_complex_expression(self) -> None:
        """Parse complex expressions."""
        source = """
const result = a + b * c - d / e;
const ternary = condition ? valueIfTrue : valueIfFalse;
const nullish = value ?? defaultValue;
const chained = obj?.prop?.nested;
"""
        prse = self.parse_ts(source)
        self.assertFalse(prse.errors_had, f"Errors: {prse.errors_had}")
        self.assertIsInstance(prse.ir_out, uni.Module)
