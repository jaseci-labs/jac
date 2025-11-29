"""Test pass module."""

# from jaclang.compiler.passes.main import SymTabBuildPass


# def test_name_collision(fixture_path) -> None:
#     """Basic test for pass."""
#     from jaclang.compiler.program import JacProgram
#     state = JacProgram().jac_file_to_pass(
#         fixture_path("multi_def_err.jac"), SymTabBuildPass
#     )
#     assert len(state.warnings_had) > 0
#     assert "MyObject" in str(state.warnings_had[0])
