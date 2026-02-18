"""Test suite for Jac language server features."""

import asyncio;
import os;
import tempfile;

import from lsprotocol.types {
    DidChangeTextDocumentParams,
    DidOpenTextDocumentParams,
    DidSaveTextDocumentParams,
    DocumentFormattingParams,
    FormattingOptions,
    SemanticTokens,
    TextDocumentIdentifier,
    TextDocumentItem,
    TextEdit,
    VersionedTextDocumentIdentifier
}

import from jaclang.langserve.engine { JacLangServer }
import from jaclang.langserve.server { formatting }
import from jaclang.vendor.pygls.uris { from_fs_path }
import from jaclang.vendor.pygls.workspace { Workspace }

# --- Utility functions inlined from utils.py ---
"""Create a temporary Jac file with optional initial content and return its path."""
def create_temp_jac_file(initial_content: str = "") -> str {
    with tempfile.NamedTemporaryFile(
        delete=False, suffix=".jac", mode="w", encoding="utf-8"
    ) as tmp {
        tmp.write(initial_content);
        return tmp.name;
    }
}

"""Load a Jac template file and inject code into placeholder."""
def load_jac_template(template_file: str, code: str = "") -> str {
    with open(template_file) as f {
        jac_template = f.read();
    }
    return jac_template.replace("#{{INJECT_CODE}}", code);
}

"""Create JacLangServer and workspace for a given file path, return (uri, ls)."""
def create_ls_with_workspace(file_path: str) -> tuple[str | None, JacLangServer] {
    ls = JacLangServer();
    uri = from_fs_path(file_path);
    ls.lsp._workspace = Workspace(os.path.dirname(file_path), ls);
    return (uri, ls);
}

"""Get absolute path to test template file."""
def get_template_path(file_name: str) -> str {
    return os.path.abspath(os.path.join(os.path.dirname(__file__), file_name));
}

"""Create a test file from a template."""
def create_test_file(template_name: str, content: str = "") -> JacTestFile {
    code = load_jac_template(get_template_path(template_name), content);
    temp_path = create_temp_jac_file(code);
    uri = from_fs_path(temp_path);
    return JacTestFile(path=temp_path, uri=uri or "", code=code);
}

# --- JacTestFile dataclass ---
obj JacTestFile {
    has path: str,
        uri: str,
        code: str,
        version: int = 1;

    def cleanup -> None {
        if os.path.exists(self.path) {
            os.remove(self.path);
        }
    }

    def increment_version -> int {
        self.version += 1;
        return self.version;
    }
}

# --- LanguageServerTestHelper ---
obj LanguageServerTestHelper {
    has ls: JacLangServer,
        test_file: JacTestFile;

    def open_document -> None {
        import from jaclang.langserve.server { did_open }

        open_params = DidOpenTextDocumentParams(
            text_document=TextDocumentItem(
                uri=self.test_file.uri,
                language_id="jac",
                version=self.test_file.version,
                text=self.test_file.code
            )
        );
        asyncio.run(did_open(self.ls, open_params));
        self.ls.wait_till_idle_sync(self.test_file.uri);
    }

    def save_document(code: str | None = None) -> None {
        import from jaclang.langserve.server { did_save }

        content = code if code is not None else self.test_file.code;
        version = self.test_file.increment_version();

        if code {
            self._update_workspace(code, version);
        }

        save_params = DidSaveTextDocumentParams(
            text_document=TextDocumentIdentifier(uri=self.test_file.uri), text=content
        );
        asyncio.run(did_save(self.ls, save_params));
        self.ls.wait_till_idle_sync(self.test_file.uri);
    }

    def change_document(code: str) -> None {
        import from jaclang.langserve.server { did_change }

        version = self.test_file.increment_version();
        self._update_workspace(code, version);

        change_params = DidChangeTextDocumentParams(
            text_document=VersionedTextDocumentIdentifier(
                uri=self.test_file.uri, version=version
            ),
            content_changes=[{"text": code}]
        );
        asyncio.run(did_change(self.ls, change_params));
        self.ls.wait_till_idle_sync(self.test_file.uri);
    }

    def _update_workspace(code: str, version: int) -> None {
        self.ls.workspace.put_text_document(
            TextDocumentItem(
                uri=self.test_file.uri, language_id="jac", version=version, text=code
            )
        );
    }

    def get_diagnostics -> list {
        return self.ls.diagnostics.get(self.test_file.uri, []);
    }

    def get_semantic_tokens -> SemanticTokens {
        return self.ls.get_semantic_tokens(self.test_file.uri);
    }

    def assert_no_diagnostics -> None {
        diagnostics = self.get_diagnostics();
        assert isinstance(diagnostics, list);
        assert len(diagnostics) == 0 , f"Expected no diagnostics, found {len(
            diagnostics
        )}";
    }

    def assert_has_diagnostics(
        count: int = 1, message_contains: str | None = None
    ) -> None {
        diagnostics = self.get_diagnostics();
        assert isinstance(diagnostics, list);
        assert len(diagnostics) == count , f"Expected {count} diagnostic(s), found {len(
            diagnostics
        )}";

        if message_contains {
            assert any(message_contains in diag.message for diag in diagnostics) , (
                f"Expected '{message_contains}' in diagnostic messages: {[
                    d.message for d in diagnostics
                ]}"
            );
        }
    }

    def assert_semantic_tokens_count(expected_count: int) -> None {
        tokens = self.get_semantic_tokens();
        assert hasattr(tokens, "data");
        assert isinstance(tokens.data, list);
        assert len(tokens.data) == expected_count , (
            f"Expected {expected_count} tokens, found {len(tokens.data)}"
        );
    }
}

# --- Constants ---
glob CIRCLE_TEMPLATE = "circle_template.jac",
     GLOB_TEMPLATE = "glob_template.jac",
     EXPECTED_CIRCLE_TOKEN_COUNT = 345,
     EXPECTED_CIRCLE_TOKEN_COUNT_ERROR = 345,
     EXPECTED_GLOB_TOKEN_COUNT = 15,
     EXPECTED_GLOB_ERROR_TOKEN_COUNT = 15;

# --- Tests ---
test "open valid file no diagnostics" {
    test_file = create_test_file(CIRCLE_TEMPLATE);
    (uri, ls) = create_ls_with_workspace(test_file.path);
    test_file.uri = uri;
    helper = LanguageServerTestHelper(ls=ls, test_file=test_file);

    try {
        helper.open_document();
        helper.assert_no_diagnostics();
    } finally {
        ls.shutdown();
        test_file.cleanup();
    }
}

test "open with syntax error" {
    test_file = create_test_file(CIRCLE_TEMPLATE, "error");
    (uri, ls) = create_ls_with_workspace(test_file.path);
    if uri {
        test_file.uri = uri;
    }
    helper = LanguageServerTestHelper(ls=ls, test_file=test_file);

    try {
        helper.open_document();
        helper.assert_has_diagnostics(count=1, message_contains="Unexpected token");

        diagnostics = helper.get_diagnostics();
        assert str(diagnostics[0].range) == "57:0-57:5";
    } finally {
        ls.shutdown();
        test_file.cleanup();
    }
}

test "did open and simple syntax error" {
    test_file = create_test_file(CIRCLE_TEMPLATE);
    (uri, ls) = create_ls_with_workspace(test_file.path);
    test_file.uri = uri;
    helper = LanguageServerTestHelper(ls=ls, test_file=test_file);

    try {
        # Open valid file
        print("Opening valid file...");
        helper.open_document();
        helper.assert_no_diagnostics();

        # Introduce syntax error
        broken_code = load_jac_template(get_template_path(CIRCLE_TEMPLATE), "error");
        helper.change_document(broken_code);
        helper.assert_has_diagnostics(count=1);
        helper.assert_semantic_tokens_count(EXPECTED_CIRCLE_TOKEN_COUNT_ERROR);
    } finally {
        ls.shutdown();
        test_file.cleanup();
    }
}

test "did save" {
    test_file = create_test_file(CIRCLE_TEMPLATE);
    (uri, ls) = create_ls_with_workspace(test_file.path);
    if uri {
        test_file.uri = uri;
    }
    helper = LanguageServerTestHelper(ls=ls, test_file=test_file);

    try {
        helper.open_document();
        helper.save_document();
        helper.assert_no_diagnostics();

        # Save with syntax error
        broken_code = load_jac_template(get_template_path(CIRCLE_TEMPLATE), "error");
        helper.save_document(broken_code);
        helper.assert_semantic_tokens_count(EXPECTED_CIRCLE_TOKEN_COUNT_ERROR);
        helper.assert_has_diagnostics(count=1, message_contains="Unexpected token");
    } finally {
        ls.shutdown();
        test_file.cleanup();
    }
}

test "did change" {
    test_file = create_test_file(CIRCLE_TEMPLATE);
    (uri, ls) = create_ls_with_workspace(test_file.path);
    if uri {
        test_file.uri = uri;
    }
    helper = LanguageServerTestHelper(ls=ls, test_file=test_file);

    try {
        helper.open_document();

        # Change without error
        helper.change_document("\n" + test_file.code);
        helper.assert_no_diagnostics();

        # Change with syntax error
        helper.change_document("\nerror" + test_file.code);
        helper.assert_semantic_tokens_count(EXPECTED_CIRCLE_TOKEN_COUNT);
        helper.assert_has_diagnostics(
            count=1, message_contains="Unexpected token 'error'"
        );
    } finally {
        ls.shutdown();
        test_file.cleanup();
    }
}

test "vsce formatting" {
    test_file = create_test_file(CIRCLE_TEMPLATE);
    (uri, ls) = create_ls_with_workspace(test_file.path);

    try {
        fmt_params = DocumentFormattingParams(
            text_document=TextDocumentIdentifier(uri=uri or ""),
            options=FormattingOptions(tab_size=4, insert_spaces=True)
        );
        edits = formatting(ls, fmt_params);

        assert isinstance(edits, list);
        assert len(edits) > 0;
        assert isinstance(edits[0], TextEdit);
        assert len(edits[0].new_text) > 100;
    } finally {
        ls.shutdown();
        test_file.cleanup();
    }
}

test "multifile workspace" {
    file1 = create_test_file(GLOB_TEMPLATE);
    file2 = create_test_file(GLOB_TEMPLATE, "error");

    (uri1, ls) = create_ls_with_workspace(file1.path);
    if uri1 {
        file1.uri = uri1;
    }
    file2_uri = from_fs_path(file2.path);
    if file2_uri {
        file2.uri = file2_uri;
    }

    helper1 = LanguageServerTestHelper(ls=ls, test_file=file1);
    helper2 = LanguageServerTestHelper(ls=ls, test_file=file2);

    try {
        # Open both files
        helper1.open_document();
        helper2.open_document();

        # Verify initial state
        helper1.assert_no_diagnostics();
        helper2.assert_has_diagnostics(count=1, message_contains="Unexpected token");

        # Check semantic tokens before change
        helper1.assert_semantic_tokens_count(EXPECTED_GLOB_TOKEN_COUNT);
        helper2.assert_semantic_tokens_count(EXPECTED_GLOB_ERROR_TOKEN_COUNT);

        # Change first file
        changed_code = load_jac_template(
            get_template_path(GLOB_TEMPLATE), "glob x = 90;"
        );
        helper1.change_document(changed_code);

        # Verify semantic tokens after change
        helper1.assert_semantic_tokens_count(20);
        helper2.assert_semantic_tokens_count(EXPECTED_GLOB_ERROR_TOKEN_COUNT);
    } finally {
        ls.shutdown();
        file1.cleanup();
        file2.cleanup();
    }
}
