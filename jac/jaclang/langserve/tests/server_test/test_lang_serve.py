"""Test suite for Jac language server features."""

import pytest

from lsprotocol.types import (
    DocumentFormattingParams,
    TextEdit,
    TextDocumentIdentifier,
)
from jaclang.langserve.tests.server_test.utils import (
    TestFile,
    LanguageServerTestHelper,
    create_ls_with_workspace,
    load_jac_template,
)
from jaclang.vendor.pygls.uris import from_fs_path
from jaclang.langserve.server import formatting


class TestLangServe:
    """Test suite for Jac language server features."""
    
    CIRCLE_TEMPLATE = "circle_template.jac"
    GLOB_TEMPLATE = "glob_template.jac"
    EXPECTED_CIRCLE_TOKEN_COUNT = 340
    EXPECTED_GLOB_TOKEN_COUNT = 15
    
    @pytest.mark.asyncio
    async def test_open_valid_file_no_diagnostics(self):
        """Test opening a valid Jac file produces no diagnostics."""
        test_file = TestFile.from_template(self.CIRCLE_TEMPLATE)
        uri, ls = create_ls_with_workspace(test_file.path)
        test_file.uri = uri
        helper = LanguageServerTestHelper(ls, test_file)
        
        await helper.open_document()
        helper.assert_no_diagnostics()
        
        ls.shutdown()
        test_file.cleanup()
    
    @pytest.mark.asyncio
    async def test_open_with_syntax_error(self):
        """Test opening a Jac file with syntax error produces diagnostics."""
        test_file = TestFile.from_template(self.CIRCLE_TEMPLATE, "error")
        uri, ls = create_ls_with_workspace(test_file.path)
        if uri:
            test_file.uri = uri
        helper = LanguageServerTestHelper(ls, test_file)
        
        await helper.open_document()
        helper.assert_has_diagnostics(count=1, message_contains="Unexpected token 'error'")
        
        diagnostics = helper.get_diagnostics()
        assert str(diagnostics[0].range) == "65:0-65:5"
        
        ls.shutdown()
        test_file.cleanup()
    
    @pytest.mark.asyncio
    async def test_did_open_and_simple_syntax_error(self):
        """Test diagnostics evolution from valid to invalid code."""
        test_file = TestFile.from_template(self.CIRCLE_TEMPLATE)
        uri, ls = create_ls_with_workspace(test_file.path)
        test_file.uri = uri
        helper = LanguageServerTestHelper(ls, test_file)
        
        # Open valid file
        print("Opening valid file...")
        await helper.open_document()
        helper.assert_no_diagnostics()
        
        # Introduce syntax error
        broken_code = load_jac_template(
            test_file._get_template_path(self.CIRCLE_TEMPLATE), 
            "error"
        )
        await helper.change_document(broken_code)
        helper.assert_has_diagnostics(count=1)
        helper.assert_semantic_tokens_count(self.EXPECTED_CIRCLE_TOKEN_COUNT)
        
        ls.shutdown()
        test_file.cleanup()
    
    @pytest.mark.asyncio
    async def test_did_save(self):
        """Test saving a Jac file triggers appropriate diagnostics."""
        test_file = TestFile.from_template(self.CIRCLE_TEMPLATE)
        uri, ls = create_ls_with_workspace(test_file.path)
        if uri:
            test_file.uri = uri
        helper = LanguageServerTestHelper(ls, test_file)
        
        await helper.open_document()
        await helper.save_document()
        helper.assert_no_diagnostics()
        
        # Save with syntax error
        broken_code = load_jac_template(
            test_file._get_template_path(self.CIRCLE_TEMPLATE),
            "error"
        )
        await helper.save_document(broken_code)
        helper.assert_semantic_tokens_count(self.EXPECTED_CIRCLE_TOKEN_COUNT)
        helper.assert_has_diagnostics(count=1, message_contains="Unexpected token 'error'")
        
        ls.shutdown()
        test_file.cleanup()
    
    @pytest.mark.asyncio
    async def test_did_change(self):
        """Test changing a Jac file triggers diagnostics."""
        test_file = TestFile.from_template(self.CIRCLE_TEMPLATE)
        uri, ls = create_ls_with_workspace(test_file.path)
        if uri:
            test_file.uri = uri
        helper = LanguageServerTestHelper(ls, test_file)
        
        await helper.open_document()
        
        # Change without error
        await helper.change_document("\n" + test_file.code)
        helper.assert_no_diagnostics()
        
        # Change with syntax error
        await helper.change_document("\nerror" + test_file.code)
        helper.assert_semantic_tokens_count(self.EXPECTED_CIRCLE_TOKEN_COUNT)
        helper.assert_has_diagnostics(count=1, message_contains="Unexpected token")
        
        ls.shutdown()
        test_file.cleanup()
    
    def test_vsce_formatting(self):
        """Test formatting a Jac file returns valid edits."""
        test_file = TestFile.from_template(self.CIRCLE_TEMPLATE)
        uri, ls = create_ls_with_workspace(test_file.path)
        
        from lsprotocol.types import FormattingOptions
        
        params = DocumentFormattingParams(
            text_document=TextDocumentIdentifier(uri=uri or ""),
            options=FormattingOptions(tab_size=4, insert_spaces=True),
        )
        edits = formatting(ls, params)
        
        assert isinstance(edits, list)
        assert len(edits) > 0
        assert isinstance(edits[0], TextEdit)
        assert len(edits[0].new_text) > 100
        
        ls.shutdown()
        test_file.cleanup()
    
    @pytest.mark.asyncio
    async def test_multifile_workspace(self):
        """Test opening multiple Jac files in a workspace."""
        file1 = TestFile.from_template(self.GLOB_TEMPLATE)
        file2 = TestFile.from_template(self.GLOB_TEMPLATE, "error")
        
        uri1, ls = create_ls_with_workspace(file1.path)
        if uri1:
            file1.uri = uri1
        file2_uri = from_fs_path(file2.path)
        if file2_uri:
            file2.uri = file2_uri
        
        helper1 = LanguageServerTestHelper(ls, file1)
        helper2 = LanguageServerTestHelper(ls, file2)
        
        # Open both files
        await helper1.open_document()
        await helper2.open_document()
        
        # Verify initial state
        helper1.assert_no_diagnostics()
        helper2.assert_has_diagnostics(count=1, message_contains="Unexpected token")
        
        # Check semantic tokens before change
        helper1.assert_semantic_tokens_count(self.EXPECTED_GLOB_TOKEN_COUNT)
        helper2.assert_semantic_tokens_count(self.EXPECTED_GLOB_TOKEN_COUNT)
        
        # Change first file
        changed_code = load_jac_template(
            file1._get_template_path(self.GLOB_TEMPLATE),
            "glob x = 90;"
        )
        await helper1.change_document(changed_code)
        
        # Verify semantic tokens after change
        helper1.assert_semantic_tokens_count(20)
        helper2.assert_semantic_tokens_count(self.EXPECTED_GLOB_TOKEN_COUNT)
        
        ls.shutdown()
        file1.cleanup()
        file2.cleanup()