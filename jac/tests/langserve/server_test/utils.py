"""Unit test utilities for JacLangServer."""

from __future__ import annotations

import asyncio
import os
import tempfile
from dataclasses import dataclass
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from jaclang.langserve.engine import JacLangServer

from lsprotocol.types import (
    DidChangeTextDocumentParams,
    DidOpenTextDocumentParams,
    DidSaveTextDocumentParams,
    SemanticTokens,
    TextDocumentItem,
    VersionedTextDocumentIdentifier,
)

from jaclang.vendor.pygls.uris import from_fs_path
from jaclang.vendor.pygls.workspace import Workspace


def create_temp_jac_file(initial_content: str = "") -> str:
    """Create a temporary Jac file with optional initial content and return its path."""
    with tempfile.NamedTemporaryFile(
        delete=False, suffix=".jac", mode="w", encoding="utf-8"
    ) as temp:
        temp.write(initial_content)
        return temp.name


def load_jac_template(template_file: str, code: str = "") -> str:
    """Load a Jac template file and inject code into placeholder."""
    with open(template_file) as f:
        jac_template = f.read()
    return jac_template.replace("#{{INJECT_CODE}}", code)


def create_ls_with_workspace(file_path: str) -> tuple[str | None, JacLangServer]:
    """Create JacLangServer and workspace for a given file path, return (uri, ls)."""
    from jaclang.langserve.engine import JacLangServer

    ls = JacLangServer()
    uri = from_fs_path(file_path)
    ls.lsp._workspace = Workspace(os.path.dirname(file_path), ls)
    return uri, ls


@dataclass
class JacTestFile:
    """Encapsulates test file information and operations."""

    path: str
    uri: str
    code: str
    version: int = 1

    @classmethod
    def from_template(cls, template_name: str, content: str = "") -> JacTestFile:
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
        return os.path.abspath(os.path.join(os.path.dirname(__file__), file_name))

    def cleanup(self) -> None:
        """Remove temporary test file."""
        if os.path.exists(self.path):
            os.remove(self.path)

    def increment_version(self) -> int:
        """Increment and return the version number."""
        self.version += 1
        return self.version


class LanguageServerTestHelper:
    """Helper class for language server testing operations."""

    def __init__(self, ls: JacLangServer, test_file: JacTestFile) -> None:
        self.ls = ls
        self.test_file = test_file

    def open_document(self) -> None:
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
        asyncio.run(did_open(self.ls, params))
        self.ls.wait_till_idle_sync(self.test_file.uri)

    def save_document(self, code: str | None = None) -> None:
        """Save a document in the language server."""
        from jaclang.langserve.server import did_save

        content = code if code is not None else self.test_file.code
        version = self.test_file.increment_version()

        if code:
            self._update_workspace(code, version)

        from lsprotocol.types import TextDocumentIdentifier

        params = DidSaveTextDocumentParams(
            text_document=TextDocumentIdentifier(uri=self.test_file.uri), text=content
        )
        asyncio.run(did_save(self.ls, params))
        self.ls.wait_till_idle_sync(self.test_file.uri)

    def change_document(self, code: str) -> None:
        """Change document content in the language server."""
        from jaclang.langserve.server import did_change

        version = self.test_file.increment_version()
        self._update_workspace(code, version)

        params = DidChangeTextDocumentParams(
            text_document=VersionedTextDocumentIdentifier(
                uri=self.test_file.uri, version=version
            ),
            content_changes=[{"text": code}],  # type: ignore
        )
        asyncio.run(did_change(self.ls, params))
        self.ls.wait_till_idle_sync(self.test_file.uri)

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

    def get_semantic_tokens(self) -> SemanticTokens:
        """Get semantic tokens for the current document."""
        return self.ls.get_semantic_tokens(self.test_file.uri)

    def assert_no_diagnostics(self) -> None:
        """Assert that there are no diagnostics."""
        diagnostics = self.get_diagnostics()
        assert isinstance(diagnostics, list)
        assert len(diagnostics) == 0, (
            f"Expected no diagnostics, found {len(diagnostics)}"
        )

    def assert_has_diagnostics(
        self, count: int = 1, message_contains: str | None = None
    ) -> None:
        """Assert that diagnostics exist with optional message validation."""
        diagnostics = self.get_diagnostics()
        assert isinstance(diagnostics, list)
        assert len(diagnostics) == count, (
            f"Expected {count} diagnostic(s), found {len(diagnostics)}"
        )

        if message_contains:
            assert any(message_contains in diag.message for diag in diagnostics), (
                f"Expected '{message_contains}' in diagnostic messages: {[d.message for d in diagnostics]}"
            )

    def assert_semantic_tokens_count(self, expected_count: int) -> None:
        """Assert semantic tokens data has expected count."""
        tokens = self.get_semantic_tokens()
        assert hasattr(tokens, "data")
        assert isinstance(tokens.data, list)
        assert len(tokens.data) == expected_count, (
            f"Expected {expected_count} tokens, found {len(tokens.data)}"
        )
