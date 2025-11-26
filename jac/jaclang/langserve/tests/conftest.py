"""Pytest configuration for langserve tests."""

import gc
import pytest


# Filter ResourceWarnings from pygls internal event loop/socket management.
# These occur because the LanguageServer creates its own event loop that
# isn't fully closed when running in test mode.
def pytest_configure(config):
    """Configure pytest to filter expected resource warnings from LSP tests."""
    config.addinivalue_line(
        "filterwarnings",
        "ignore::ResourceWarning",
    )


@pytest.fixture(autouse=True)
def cleanup_gc():
    """Force garbage collection after each test to clean up resources."""
    yield
    gc.collect()
