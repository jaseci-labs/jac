"""The public API must reject misuse through Jac's actual static checker."""
import from pathlib { Path }
import os;
import re;
import subprocess;
import sys;
import unittest;
import from .sql_cases { run_case }
glob ROOT = Path(__file__).resolve().parents[3];
class StaticTypes(unittest.TestCase) {
    def test_positive_module_and_calls(self: StaticTypes) -> object {
        result = subprocess.run(
            [
                sys.executable,
                '-m',
                'jaclang',
                'check',
                'jac/jaclang/sql.jac',
                'jac/tests/sql/fixtures/valid_calls.jac'
            ],
            cwd=ROOT,
            capture_output=True,
            text=True
        );
        self.assertEqual(result.returncode, 0, (result.stdout + result.stderr));
        self.assertIn('2 passed', (result.stdout + result.stderr));
    }

    def test_all_bad_calls_are_rejected_at_their_lines(self: StaticTypes) -> object {
        fixture = ROOT / 'jac/tests/sql/fixtures/invalid_calls.jac';
        result = subprocess.run(
            [sys.executable, '-m', 'jaclang', 'check', str(fixture)],
            cwd=ROOT,
            capture_output=True,
            text=True
        );
        output = result.stdout + result.stderr;
        self.assertNotEqual(result.returncode, 0, output);
        lines = {int(x) for x in re.findall(r'invalid_calls\.jac:(\d+):\d+', output)};
        self.assertEqual(lines, {7, 8, 9, 10, 11, 12, 13, 14, 17, 18, 19}, output);
        self.assertEqual(output.count('error[E1053]'), 11, output);
    }

    def test_temporary_names_are_not_api_arguments(self: StaticTypes) -> object {
        fixture = ROOT / 'jac/tests/sql/fixtures/invalid_cte_calls.jac';
        result = subprocess.run(
            [sys.executable, '-m', 'jaclang', 'check', str(fixture)],
            cwd=ROOT,
            capture_output=True,
            text=True
        );
        output = result.stdout + result.stderr;
        self.assertNotEqual(result.returncode, 0, output);
        lines = {
            int(x) for x in re.findall(r'invalid_cte_calls\.jac:(\d+):\d+', output)
        };
        self.assertEqual(lines, {4, 5, 7}, output);
        self.assertEqual(output.count('error[E1053]'), 3, output);
    }

    def test_advanced_invalid_arguments(self: StaticTypes) -> object {
        fixture = ROOT / 'jac/tests/sql/fixtures/invalid_advanced_calls.jac';
        result = subprocess.run(
            [sys.executable, '-m', 'jaclang', 'check', str(fixture)],
            cwd=ROOT,
            capture_output=True,
            text=True
        );
        output = result.stdout + result.stderr;
        self.assertNotEqual(result.returncode, 0, output);
        expected = {
            i
            for (i, line) in enumerate(fixture.read_text().splitlines(), 1)
            if '# invalid' in line
        };
        actual = {
            int(x) for x in re.findall(r'invalid_advanced_calls\.jac:(\d+):\d+', output)
        };
        self.assertEqual(actual, expected, output);
    }

    def test_typed_builder_arguments(self: StaticTypes) -> object {
        fixture = ROOT / 'jac/tests/sql/fixtures/invalid_typed_builders.jac';
        result = subprocess.run(
            [sys.executable, '-m', 'jaclang', 'check', str(fixture)],
            cwd=ROOT,
            capture_output=True,
            text=True
        );
        output = result.stdout + result.stderr;
        self.assertNotEqual(result.returncode, 0, output);
        expected = {
            i
            for (i, line) in enumerate(fixture.read_text().splitlines(), 1)
            if '# invalid' in line
        };
        actual = {
            int(x) for x in re.findall(r'invalid_typed_builders\.jac:(\d+):\d+', output)
        };
        self.assertEqual(actual, expected, output);
    }
}


test "Static types: positive module and calls" {
    run_case(StaticTypes("test_positive_module_and_calls"));
}

test "Static types: all bad calls are rejected at their lines" {
    run_case(StaticTypes("test_all_bad_calls_are_rejected_at_their_lines"));
}

test "Static types: temporary names are not API arguments" {
    run_case(StaticTypes("test_temporary_names_are_not_api_arguments"));
}

test "Static types: advanced SQL arguments" {
    run_case(StaticTypes("test_advanced_invalid_arguments"));
}

test "Static types: typed builders reject invalid arguments" {
    run_case(StaticTypes("test_typed_builder_arguments"));
}
