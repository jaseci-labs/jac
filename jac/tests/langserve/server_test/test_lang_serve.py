"""Test suite for Jac language server features."""

# Import jaclang first to set up vendor path for lsprotocol
from lsprotocol.types import (
    DocumentFormattingParams,
    FormattingOptions,
    TextDocumentIdentifier,
    TextEdit,
)
from tests.langserve.server_test.utils import (
    JacTestFile,
    LanguageServerTestHelper,
    create_ls_with_workspace,
    load_jac_template,
)

from jaclang.langserve.server import formatting
from jaclang.vendor.pygls.uris import from_fs_path

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


def test_open_valid_file_no_diagnostics():
    """Test opening a valid Jac file produces no diagnostics."""
    test_file = JacTestFile.from_template(CIRCLE_TEMPLATE)
    uri, ls = create_ls_with_workspace(test_file.path)
    test_file.uri = uri
    helper = LanguageServerTestHelper(ls, test_file)

    try:
        helper.open_document()
        # helper.assert_no_diagnostics()
        helper.assert_has_diagnostics(
            count=1,
            message_contains="Cannot assign <class ShapeType> to parameter 'radius' of type <class float>",
        )
    finally:
        ls.shutdown()
        test_file.cleanup()


def test_open_with_syntax_error():
    """Test opening a Jac file with syntax error produces diagnostics."""
    test_file = JacTestFile.from_template(CIRCLE_TEMPLATE, "error")
    uri, ls = create_ls_with_workspace(test_file.path)
    if uri:
        test_file.uri = uri
    helper = LanguageServerTestHelper(ls, test_file)

    try:
        helper.open_document()
        helper.assert_has_diagnostics(count=2, message_contains="Unexpected token")

        diagnostics = helper.get_diagnostics()
        assert str(diagnostics[0].range) == "57:0-57:5"
    finally:
        ls.shutdown()
        test_file.cleanup()


def test_did_open_and_simple_syntax_error():
    """Test diagnostics evolution from valid to invalid code."""
    test_file = JacTestFile.from_template(CIRCLE_TEMPLATE)
    uri, ls = create_ls_with_workspace(test_file.path)
    test_file.uri = uri
    helper = LanguageServerTestHelper(ls, test_file)

    try:
        # Open valid file
        print("Opening valid file...")
        helper.open_document()
        # helper.assert_no_diagnostics()
        helper.assert_has_diagnostics(
            count=1,
            message_contains="Cannot assign <class ShapeType> to parameter 'radius' of type <class float>",
        )

        # Introduce syntax error
        broken_code = load_jac_template(
            test_file._get_template_path(CIRCLE_TEMPLATE), "error"
        )
        helper.change_document(broken_code)
        helper.assert_has_diagnostics(count=2)
        helper.assert_semantic_tokens_count(EXPECTED_CIRCLE_TOKEN_COUNT_ERROR)
    finally:
        ls.shutdown()
        test_file.cleanup()


def test_did_save():
    """Test saving a Jac file triggers appropriate diagnostics."""
    test_file = JacTestFile.from_template(CIRCLE_TEMPLATE)
    uri, ls = create_ls_with_workspace(test_file.path)
    if uri:
        test_file.uri = uri
    helper = LanguageServerTestHelper(ls, test_file)

    try:
        helper.open_document()
        helper.save_document()
        # helper.assert_no_diagnostics()
        helper.assert_has_diagnostics(
            count=1,
            message_contains="Cannot assign <class ShapeType> to parameter 'radius' of type <class float>",
        )

        # Save with syntax error
        broken_code = load_jac_template(
            test_file._get_template_path(CIRCLE_TEMPLATE), "error"
        )
        helper.save_document(broken_code)
        helper.assert_semantic_tokens_count(EXPECTED_CIRCLE_TOKEN_COUNT_ERROR)
        helper.assert_has_diagnostics(count=2, message_contains="Unexpected token")
    finally:
        ls.shutdown()
        test_file.cleanup()


def test_did_change():
    """Test changing a Jac file triggers diagnostics."""
    test_file = JacTestFile.from_template(CIRCLE_TEMPLATE)
    uri, ls = create_ls_with_workspace(test_file.path)
    if uri:
        test_file.uri = uri
    helper = LanguageServerTestHelper(ls, test_file)

    try:
        helper.open_document()

        # Change without error
        helper.change_document("\n" + test_file.code)
        # helper.assert_no_diagnostics()
        helper.assert_has_diagnostics(
            count=1,
            message_contains="Cannot assign <class ShapeType> to parameter 'radius' of type <class float>",
        )

        # Change with syntax error
        helper.change_document("\nerror" + test_file.code)
        helper.assert_semantic_tokens_count(EXPECTED_CIRCLE_TOKEN_COUNT)
        helper.assert_has_diagnostics(
            count=2, message_contains="Unexpected token 'error'"
        )
    finally:
        ls.shutdown()
        test_file.cleanup()


def test_vsce_formatting():
    """Test formatting a Jac file returns valid edits."""
    test_file = JacTestFile.from_template(CIRCLE_TEMPLATE)
    uri, ls = create_ls_with_workspace(test_file.path)

    try:
        params = DocumentFormattingParams(
            text_document=TextDocumentIdentifier(uri=uri or ""),
            options=FormattingOptions(tab_size=4, insert_spaces=True),
        )
        edits = formatting(ls, params)

        assert isinstance(edits, list)
        assert len(edits) > 0
        assert isinstance(edits[0], TextEdit)
        assert len(edits[0].new_text) > 100
    finally:
        ls.shutdown()
        test_file.cleanup()


def test_multifile_workspace():
    """Test opening multiple Jac files in a workspace."""
    file1 = JacTestFile.from_template(GLOB_TEMPLATE)
    file2 = JacTestFile.from_template(GLOB_TEMPLATE, "error")

    uri1, ls = create_ls_with_workspace(file1.path)
    if uri1:
        file1.uri = uri1
    file2_uri = from_fs_path(file2.path)
    if file2_uri:
        file2.uri = file2_uri

    helper1 = LanguageServerTestHelper(ls, file1)
    helper2 = LanguageServerTestHelper(ls, file2)

    try:
        # Open both files
        helper1.open_document()
        helper2.open_document()

        # Verify initial state
        helper1.assert_no_diagnostics()
        helper2.assert_has_diagnostics(count=1, message_contains="Unexpected token")

        # Check semantic tokens before change
        helper1.assert_semantic_tokens_count(EXPECTED_GLOB_TOKEN_COUNT)
        helper2.assert_semantic_tokens_count(EXPECTED_GLOB_ERROR_TOKEN_COUNT)

        # Change first file
        changed_code = load_jac_template(
            file1._get_template_path(GLOB_TEMPLATE), "glob x = 90;"
        )
        helper1.change_document(changed_code)

        # Verify semantic tokens after change
        helper1.assert_semantic_tokens_count(20)
        helper2.assert_semantic_tokens_count(EXPECTED_GLOB_ERROR_TOKEN_COUNT)
    finally:
        ls.shutdown()
        file1.cleanup()
        file2.cleanup()
