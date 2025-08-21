"""Test ast build pass module."""

import ast as ast3
from difflib import unified_diff


from jaclang.compiler.passes.tool import JacFormatPass
from jaclang.compiler.program import JacProgram
from jaclang.utils.test import TestCaseMicroSuite


class JacUnparseTests(TestCaseMicroSuite):
    """Test pass module."""

    TargetPass = JacFormatPass

    def test_double_unparse(self) -> None:
        """Parse micro jac file."""
        try:
            code_gen_pure = JacProgram().compile(
                self.examples_abs_path("manual_code/circle.jac")
            )
            x = code_gen_pure.unparse()
            y = code_gen_pure.unparse()
            self.assertEqual(x, y)
        except Exception as e:
            print("\n".join(unified_diff(x.splitlines(), y.splitlines())))
            raise e

    def micro_suite_test(self, filename: str) -> None:
        """Parse micro jac file."""
        code_gen_pure = JacProgram().compile(
            self.fixture_abs_path(filename),
        )
        before = ast3.dump(code_gen_pure.gen.py_ast[0], indent=2)
        x = code_gen_pure.unparse()
        code_gen_jac = JacProgram().compile(
            use_str=x,
            file_path=filename,
        )
        after = ast3.dump(code_gen_jac.gen.py_ast[0], indent=2)
        if "circle_clean_tests.jac" in filename:
            self.assertEqual(
                len(
                    [
                        i
                        for i in unified_diff(
                            before.splitlines(), after.splitlines(), n=0
                        )
                        if "test" not in i
                    ]
                ),
                5,
            )
        else:
            try:
                self.assertEqual(
                    len(
                        "\n".join(unified_diff(before.splitlines(), after.splitlines()))
                    ),
                    0,
                )
            except Exception as e:
                print(
                    "\n".join(
                        unified_diff(before.splitlines(), after.splitlines(), n=10)
                    )
                )
                raise e


JacUnparseTests.self_attach_micro_tests()
