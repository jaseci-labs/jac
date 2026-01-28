"""Test suite for Jac language server features.

Tests the real multiprocessing worker architecture:
main process sends requests via queues, worker process handles
compilation, diagnostics, semantic tokens, and formatting.
"""

import os
import tempfile

from tests.langserve.server_test.utils import load_jac_template
from tests.langserve.test_server import LspTestClient, create_client

# NOTE: circle.jac emits a spurious type error at the call to super.init:
# obj Circle(Shape) {
#     def init(radius: float) {
#         super.init(ShapeType.CIRCLE);
#                    ^^^^^^^^^^^^^^^^
# The call is correct: semantically super refers to the parent class. The
# current static/type checker cannot reliably infer that relationship and
# reports a false positive. This should be fixed in the type checker.

CIRCLE_TEMPLATE = "circle_template.jac"
GLOB_TEMPLATE = "glob_template.jac"
EXPECTED_CIRCLE_TOKEN_COUNT = 355
EXPECTED_CIRCLE_TOKEN_COUNT_ERROR = 355
EXPECTED_GLOB_TOKEN_COUNT = 15
EXPECTED_GLOB_ERROR_TOKEN_COUNT = 15


def _template_path(template_name: str) -> str:
    """Get absolute path to test template file."""
    return os.path.abspath(os.path.join(os.path.dirname(__file__), template_name))


def _create_temp_jac(content: str) -> str:
    """Create a temporary .jac file with the given content, return its path."""
    with tempfile.NamedTemporaryFile(
        delete=False, suffix=".jac", mode="w", encoding="utf-8"
    ) as f:
        f.write(content)
        return f.name


def _get_diagnostics(response: dict) -> dict:
    """Extract diagnostics from a compile response."""
    return response.get("diagnostics", {"errors": [], "warnings": []})


def _count_errors(response: dict) -> int:
    """Count error diagnostics from a compile response."""
    return len(_get_diagnostics(response).get("errors", []))


def _has_error_message(response: dict, message_contains: str) -> bool:
    """Check if any error diagnostic contains the given message substring."""
    errors = _get_diagnostics(response).get("errors", [])
    return any(message_contains in e.get("message", "") for e in errors)


def _error_at(response: dict, index: int) -> dict:
    """Get error at index from compile response."""
    return _get_diagnostics(response).get("errors", [])[index]


def _sem_token_count(client: LspTestClient, file_path: str) -> int:
    """Get semantic token count for a file via the worker."""
    tok_resp = client._wm.request_semantic_tokens(file_path)
    if tok_resp and tok_resp.get("tokens"):
        return len(tok_resp["tokens"])
    return 0


def test_open_valid_file_no_diagnostics():
    """Test compiling a valid Jac file produces expected diagnostics."""
    code = load_jac_template(_template_path(CIRCLE_TEMPLATE))
    temp_path = _create_temp_jac(code)
    client = create_client()

    try:
        response = client.compile_file(temp_path)
        assert _count_errors(response) == 1, (
            f"Expected 1 error, got {_count_errors(response)}: "
            f"{_get_diagnostics(response)}"
        )
        assert _has_error_message(
            response,
            "Cannot assign <class ShapeType> to parameter 'radius' of type <class float>",
        )
    finally:
        client.shutdown()
        os.remove(temp_path)


def test_open_with_syntax_error():
    """Test compiling a Jac file with syntax error produces diagnostics."""
    code = load_jac_template(_template_path(CIRCLE_TEMPLATE), "error")
    temp_path = _create_temp_jac(code)
    client = create_client()

    try:
        response = client.compile_file(temp_path)
        assert _count_errors(response) == 2, (
            f"Expected 2 errors, got {_count_errors(response)}: "
            f"{_get_diagnostics(response)}"
        )
        assert _has_error_message(response, "Unexpected token")

        err = _error_at(response, 0)
        # Diagnostics use 1-indexed line/col from the compiler
        assert err["line"] == 58 and err["col"] == 1, (
            f"Expected error at line 58, col 1, got line {err['line']}, col {err['col']}"
        )
    finally:
        client.shutdown()
        os.remove(temp_path)


def test_did_open_and_simple_syntax_error():
    """Test diagnostics evolution from valid to invalid code."""
    code = load_jac_template(_template_path(CIRCLE_TEMPLATE))
    temp_path = _create_temp_jac(code)
    client = create_client()

    try:
        # Compile valid file
        response = client.compile_file(temp_path)
        assert _count_errors(response) == 1
        assert _has_error_message(
            response,
            "Cannot assign <class ShapeType> to parameter 'radius' of type <class float>",
        )

        # Introduce syntax error by rewriting file
        broken_code = load_jac_template(_template_path(CIRCLE_TEMPLATE), "error")
        with open(temp_path, "w") as f:
            f.write(broken_code)

        response = client.compile_file(temp_path)
        assert _count_errors(response) == 2

        token_count = _sem_token_count(client, temp_path)
        assert token_count == EXPECTED_CIRCLE_TOKEN_COUNT_ERROR, (
            f"Expected {EXPECTED_CIRCLE_TOKEN_COUNT_ERROR} tokens, got {token_count}"
        )
    finally:
        client.shutdown()
        os.remove(temp_path)


def test_did_save():
    """Test recompiling after save triggers appropriate diagnostics."""
    code = load_jac_template(_template_path(CIRCLE_TEMPLATE))
    temp_path = _create_temp_jac(code)
    client = create_client()

    try:
        # Initial compile
        response = client.compile_file(temp_path)
        assert _count_errors(response) == 1
        assert _has_error_message(
            response,
            "Cannot assign <class ShapeType> to parameter 'radius' of type <class float>",
        )

        # Recompile (simulates save without changes)
        response = client.compile_file(temp_path)
        assert _count_errors(response) == 1

        # Save with syntax error
        broken_code = load_jac_template(_template_path(CIRCLE_TEMPLATE), "error")
        with open(temp_path, "w") as f:
            f.write(broken_code)

        response = client.compile_file(temp_path)
        token_count = _sem_token_count(client, temp_path)
        assert token_count == EXPECTED_CIRCLE_TOKEN_COUNT_ERROR, (
            f"Expected {EXPECTED_CIRCLE_TOKEN_COUNT_ERROR} tokens, got {token_count}"
        )
        assert _count_errors(response) == 2
        assert _has_error_message(response, "Unexpected token")
    finally:
        client.shutdown()
        os.remove(temp_path)


def test_did_change():
    """Test recompiling after content change triggers diagnostics."""
    code = load_jac_template(_template_path(CIRCLE_TEMPLATE))
    temp_path = _create_temp_jac(code)
    client = create_client()

    try:
        # Initial compile
        client.compile_file(temp_path)

        # Change without error (prepend newline)
        with open(temp_path, "w") as f:
            f.write("\n" + code)
        response = client.compile_file(temp_path)
        assert _count_errors(response) == 1
        assert _has_error_message(
            response,
            "Cannot assign <class ShapeType> to parameter 'radius' of type <class float>",
        )

        # Change with syntax error
        with open(temp_path, "w") as f:
            f.write("\nerror" + code)
        response = client.compile_file(temp_path)
        token_count = _sem_token_count(client, temp_path)
        assert token_count == EXPECTED_CIRCLE_TOKEN_COUNT, (
            f"Expected {EXPECTED_CIRCLE_TOKEN_COUNT} tokens, got {token_count}"
        )
        assert _count_errors(response) == 2
        assert _has_error_message(response, "Unexpected token 'error'")
    finally:
        client.shutdown()
        os.remove(temp_path)


def test_vsce_formatting():
    """Test formatting a Jac file returns valid edits."""
    code = load_jac_template(_template_path(CIRCLE_TEMPLATE))
    temp_path = _create_temp_jac(code)
    client = create_client()

    try:
        resp = client._wm.request_format(temp_path, code)
        assert resp is not None, "Format response should not be None"
        assert resp.get("success"), f"Format should succeed, got: {resp}"
        formatted = resp.get("formatted", "")
        assert len(formatted) > 100, (
            f"Formatted output too short ({len(formatted)} chars)"
        )
    finally:
        client.shutdown()
        os.remove(temp_path)


def test_multifile_workspace():
    """Test compiling multiple Jac files."""
    code1 = load_jac_template(_template_path(GLOB_TEMPLATE))
    code2 = load_jac_template(_template_path(GLOB_TEMPLATE), "error")

    temp1 = _create_temp_jac(code1)
    temp2 = _create_temp_jac(code2)
    client = create_client()

    try:
        # Compile both files
        resp1 = client.compile_file(temp1)
        resp2 = client.compile_file(temp2)

        # Verify initial state
        assert _count_errors(resp1) == 0, (
            f"Expected no errors for file1, got: {_get_diagnostics(resp1)}"
        )
        assert _count_errors(resp2) == 1
        assert _has_error_message(resp2, "Unexpected token")

        # Check semantic tokens
        tok1 = _sem_token_count(client, temp1)
        tok2 = _sem_token_count(client, temp2)
        assert tok1 == EXPECTED_GLOB_TOKEN_COUNT, (
            f"Expected {EXPECTED_GLOB_TOKEN_COUNT} tokens for file1, got {tok1}"
        )
        assert tok2 == EXPECTED_GLOB_ERROR_TOKEN_COUNT, (
            f"Expected {EXPECTED_GLOB_ERROR_TOKEN_COUNT} tokens for file2, got {tok2}"
        )

        # Change first file
        changed_code = load_jac_template(_template_path(GLOB_TEMPLATE), "glob x = 90;")
        with open(temp1, "w") as f:
            f.write(changed_code)
        client.compile_file(temp1)

        # Verify semantic tokens after change
        tok1_after = _sem_token_count(client, temp1)
        tok2_after = _sem_token_count(client, temp2)
        assert tok1_after == 20, (
            f"Expected 20 tokens for changed file1, got {tok1_after}"
        )
        assert tok2_after == EXPECTED_GLOB_ERROR_TOKEN_COUNT, (
            f"Expected {EXPECTED_GLOB_ERROR_TOKEN_COUNT} tokens for file2, got {tok2_after}"
        )
    finally:
        client.shutdown()
        os.remove(temp1)
        os.remove(temp2)
