"""Test ast build pass module."""

import ast as ast3
import os
from difflib import unified_diff

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes.tool import JacFormatPass
from jaclang.compiler.program import JacProgram
from jaclang.utils.helpers import add_line_numbers
from jaclang.utils.test import AstSyncTestMixin, TestCaseMicroSuite


class JacFormatPassTests(TestCaseMicroSuite):
    """Test pass module."""

    def compare_files(self, original_file: str, formatted_file: str = None) -> None:
        """Compare the original file with a provided formatted file or a new formatted version."""
        try:
            original_path = self.fixture_abs_path(original_file)
            with open(original_path, "r") as file:
                original_file_content = file.read()
            if formatted_file is None:
                formatted_content = JacProgram.jac_file_formatter(original_path)
            else:
                with open(self.fixture_abs_path(formatted_file), "r") as file:
                    formatted_content = file.read()
            diff = "\n".join(
                unified_diff(
                    original_file_content.splitlines(),
                    formatted_content.splitlines(),
                    fromfile="original",
                    tofile="formatted" if formatted_file is None else formatted_file,
                )
            )

            if diff:
                print(f"Differences found in comparison:\n{diff}")
                raise AssertionError("Files differ after formattinclearg.")

        except FileNotFoundError:
            print(f"File not found: {original_file} or {formatted_file}")
            raise
        except Exception as e:
            print(f"Error comparing files: {e}")
            raise

    def test_simple_walk_fmt(self) -> None:
        """Tests if the file matches a particular format."""
        self.compare_files(
            os.path.join(self.fixture_abs_path(""), "simple_walk_fmt.jac"),
        )

    def test_tagbreak(self) -> None:
        """Tests if the file matches a particular format."""
        self.compare_files(
            os.path.join(self.fixture_abs_path(""), "tagbreak.jac"),
        )

    def test_has_fmt(self) -> None:
        """Tests if the file matches a particular format."""
        self.compare_files(
            os.path.join(self.fixture_abs_path(""), "has_frmt.jac"),
        )

    def test_import_fmt(self) -> None:
        """Tests if the file matches a particular format."""
        self.compare_files(
            os.path.join(self.fixture_abs_path(""), "import_fmt.jac"),
        )

    def test_archetype(self) -> None:
        """Tests if the file matches a particular format."""
        self.compare_files(
            os.path.join(self.fixture_abs_path(""), "archetype_frmt.jac"),
        )

    # def test_corelib_fmt(self) -> None:
    #     """Tests if the file matches a particular format."""
    #     self.compare_files(
    #         os.path.join(self.fixture_abs_path(""), "corelib_fmt.jac"),
    #     )

    # def test_doc_string_fmt(self) -> None:
    #     """Tests if the file matches a particular format."""
    #     self.compare_files(
    #         os.path.join(self.fixture_abs_path(""), "doc_string.jac"),
    #     )

    # def test_compare_myca_fixtures(self) -> None:
    #     """Tests if files in the myca fixtures directory do not change after being formatted."""
    #     fixtures_dir = os.path.join(self.fixture_abs_path(""), "myca_formatted_code")
    #     fixture_files = os.listdir(fixtures_dir)
    #     for file_name in fixture_files:
    #         if file_name == "__jac_gen__":
    #             continue
    #         with self.subTest(file=file_name):
    #             file_path = os.path.join(fixtures_dir, file_name)
    #             self.compare_files(file_path)

    # def test_general_format_fixtures(self) -> None:
    #     """Tests if files in the general fixtures directory do not change after being formatted."""
    #     fixtures_dir = os.path.join(self.fixture_abs_path(""), "general_format_checks")
    #     fixture_files = os.listdir(fixtures_dir)
    #     for file_name in fixture_files:
    #         if file_name == "__jac_gen__":
    #             continue
    #         with self.subTest(file=file_name):
    #             file_path = os.path.join(fixtures_dir, file_name)
    #             self.compare_files(file_path)

    def micro_suite_test(self, filename: str) -> None:
        """
        Tests the Jac formatter by:
        1. Compiling a given Jac file.
        2. Formatting the Jac file content.
        3. Compiling the formatted content.
        4. Asserting that the AST of the original compilation and the
           AST of the formatted compilation are identical.
        This ensures that the formatting process does not alter the
        syntactic structure of the code.
        Includes a specific token check for 'circle_clean_tests.jac'.
        """
        code_gen_pure = JacProgram().compile(self.fixture_abs_path(filename))
        code_gen_format = JacProgram.jac_file_formatter(self.fixture_abs_path(filename))
        code_gen_jac = JacProgram().compile(use_str=code_gen_format, file_path=filename)
        if "circle_clean_tests.jac" in filename:
            tokens = code_gen_format.split()
            num_test = 0
            for i in range(len(tokens)):
                if tokens[i] == "test":
                    num_test += 1
                    self.assertEqual(tokens[i + 1], "{")
            self.assertEqual(num_test, 3)
            return
        try:
            before = ast3.dump(code_gen_pure.gen.py_ast[0], indent=2)
            after = ast3.dump(code_gen_jac.gen.py_ast[0], indent=2)
            self.assertTrue(
                isinstance(code_gen_pure, uni.Module)
                and isinstance(code_gen_jac, uni.Module),
                "Parsed objects are not modules.",
            )

            diff = "\n".join(unified_diff(before.splitlines(), after.splitlines()))
            self.assertFalse(diff, "AST structures differ after formatting.")

        except Exception as e:
            print(f"Error in {filename}: {e}")
            print(add_line_numbers(code_gen_pure.source.code))
            print("\n+++++++++++++++++++++++++++++++++++++++\n")
            print(add_line_numbers(code_gen_format))
            print("\n+++++++++++++++++++++++++++++++++++++++\n")
            print("\n".join(unified_diff(before.splitlines(), after.splitlines())))
            raise e


JacFormatPassTests.self_attach_micro_tests()
