"""Unit test utilities for JacLangServer."""

import os
import tempfile
from typing import Optional
from dataclasses import dataclass

from lsprotocol.types import (
    DidOpenTextDocumentParams,
    TextDocumentItem,
    DidSaveTextDocumentParams,
    DidChangeTextDocumentParams,
    VersionedTextDocumentIdentifier,
)
from jaclang.vendor.pygls.uris import from_fs_path
from jaclang.vendor.pygls.workspace import Workspace


def create_temp_jac_file(initial_content: str = "") -> str:
    """Create a temporary Jac file with optional initial content and return its path."""
    temp = tempfile.NamedTemporaryFile(
        delete=False, suffix=".jac", mode="w", encoding="utf-8"
    )
    temp.write(initial_content)
    temp.close()
    return temp.name


def load_jac_template(template_file: str, code: str = "") -> str:
    """Load a Jac template file and inject code into placeholder."""
    with open(template_file, "r") as f:
        jac_template = f.read()
    return jac_template.replace("#{{INJECT_CODE}}", code)


def create_ls_with_workspace(file_path: str):
    """Create JacLangServer and workspace for a given file path, return (uri, ls)."""
    from jaclang.langserve.engine import JacLangServer

    ls = JacLangServer()
    uri = from_fs_path(file_path)
    ls.lsp._workspace = Workspace(os.path.dirname(file_path), ls)
    return uri, ls


@dataclass
class TestFile:
    """Encapsulates test file information and operations."""
    
    path: str
    uri: str
    code: str
    version: int = 1
    
    @classmethod
    def from_template(cls, template_name: str, content: str = "") -> "TestFile":
        """Create a test file from a template."""
        code = load_jac_template(cls._get_template_path(template_name), content)
        temp_path = create_temp_jac_file(code)
        uri = from_fs_path(temp_path)
        return cls(
            path=temp_path,
            uri=uri or "",
            code=code,
        )
    
    @staticmethod
    def _get_template_path(file_name: str) -> str:
        """Get absolute path to test template file."""
        return os.path.abspath(
            os.path.join(os.path.dirname(__file__), file_name)
        )
    
    def cleanup(self):
        """Remove temporary test file."""
        if os.path.exists(self.path):
            os.remove(self.path)
    
    def increment_version(self) -> int:
        """Increment and return the version number."""
        self.version += 1
        return self.version


class LanguageServerTestHelper:
    """Helper class for language server testing operations."""
    
    def __init__(self, ls, test_file: TestFile):
        self.ls = ls
        self.test_file = test_file
    
    async def open_document(self) -> None:
        """Open a document in the language server."""
        from jaclang.langserve.server import did_open
        
        params = DidOpenTextDocumentParams(
            text_document=TextDocumentItem(
                uri=self.test_file.uri,
                language_id="jac",
                version=self.test_file.version,
                text=self.test_file.code,
            )
        )
        await did_open(self.ls, params)
    
    async def save_document(self, code: Optional[str] = None) -> None:
        """Save a document in the language server."""
        from jaclang.langserve.server import did_save
        
        content = code if code is not None else self.test_file.code
        version = self.test_file.increment_version()
        
        if code:
            self._update_workspace(code, version)
        
        from lsprotocol.types import TextDocumentIdentifier
        
        params = DidSaveTextDocumentParams(
            text_document=TextDocumentIdentifier(uri=self.test_file.uri),
            text=content
        )
        await did_save(self.ls, params)
    
    async def change_document(self, code: str) -> None:
        """Change document content in the language server."""
        from jaclang.langserve.server import did_change
        
        version = self.test_file.increment_version()
        self._update_workspace(code, version)
        
        params = DidChangeTextDocumentParams(
            text_document=VersionedTextDocumentIdentifier(
                uri=self.test_file.uri,
                version=version
            ),
            content_changes=[{"text": code}],  # type: ignore
        )
        await did_change(self.ls, params)
    
    def _update_workspace(self, code: str, version: int) -> None:
        """Update workspace with new document content."""
        self.ls.workspace.put_text_document(
            TextDocumentItem(
                uri=self.test_file.uri,
                language_id="jac",
                version=version,
                text=code,
            )
        )
    
    def get_diagnostics(self) -> list:
        """Get diagnostics for the current document."""
        return self.ls.diagnostics.get(self.test_file.uri, [])
    
    def get_semantic_tokens(self):
        """Get semantic tokens for the current document."""
        return self.ls.get_semantic_tokens(self.test_file.uri)
    
    def assert_no_diagnostics(self) -> None:
        """Assert that there are no diagnostics."""
        diagnostics = self.get_diagnostics()
        assert isinstance(diagnostics, list)
        assert len(diagnostics) == 0, f"Expected no diagnostics, found {len(diagnostics)}"
    
    def assert_has_diagnostics(self, count: int = 1, message_contains: Optional[str] = None) -> None:
        """Assert that diagnostics exist with optional message validation."""
        diagnostics = self.get_diagnostics()
        assert isinstance(diagnostics, list)
        assert len(diagnostics) == count, f"Expected {count} diagnostic(s), found {len(diagnostics)}"
        
        if message_contains:
            assert message_contains in diagnostics[0].message, \
                f"Expected '{message_contains}' in diagnostic message"
    
    def assert_semantic_tokens_count(self, expected_count: int) -> None:
        """Assert semantic tokens data has expected count."""
        tokens = self.get_semantic_tokens()
        assert hasattr(tokens, "data")
        assert isinstance(tokens.data, list)
        assert len(tokens.data) == expected_count, \
            f"Expected {expected_count} tokens, found {len(tokens.data)}"
