"""DEPRECATED: Test case utils for Jaseci.

This module is deprecated. All tests have been converted to pure pytest format.
Use pytest fixtures from conftest.py instead.

For helper functions, use:
- conftest.py fixtures: fixture_path, load_fixture, examples_path, etc.
- jaclang.utils.symtable_test_helpers: assert_symbol_exists, etc.
"""

import warnings

warnings.warn(
    "jaclang.utils.test is deprecated. Use pytest fixtures from conftest.py instead.",
    DeprecationWarning,
    stacklevel=2,
)

# Keep minimal stubs for backwards compatibility if any external code uses these
__all__ = ["TestCase", "TestCaseMicroSuite", "AstSyncTestMixin"]


class TestCase:
    """DEPRECATED: Use pure pytest functions instead."""

    def __init__(self, *args, **kwargs):
        warnings.warn(
            "TestCase is deprecated. Use pure pytest functions instead.",
            DeprecationWarning,
            stacklevel=2,
        )
        raise NotImplementedError(
            "TestCase has been removed. Use pure pytest functions instead."
        )


class TestCaseMicroSuite(TestCase):
    """DEPRECATED: Use pytest parametrize instead."""

    pass


class AstSyncTestMixin:
    """DEPRECATED: Use check_pass_ast_complete() from conftest.py instead."""

    def __init__(self, *args, **kwargs):
        warnings.warn(
            "AstSyncTestMixin is deprecated. Use check_pass_ast_complete() instead.",
            DeprecationWarning,
            stacklevel=2,
        )
        raise NotImplementedError(
            "AstSyncTestMixin has been removed. Use check_pass_ast_complete() from conftest.py instead."
        )
