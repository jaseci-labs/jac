"""Test ast build pass module."""

from jaclang.compiler.passes.tool import JacFormatPass


class FuseCommentsPassTests:
    """Test pass module."""

    TargetPass = JacFormatPass

    def setUp(self) -> None:
        """Set up test."""
        return super().setUp()

    def test_simple(self) -> None:
        """Basic test for pass."""
        # code1 = f"with entry #* hi *# {{print('hi');}}"
