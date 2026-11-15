"""PDF documents: the block each accepted source becomes, and what is refused.

Assert on the request byLLM actually sent, not on a rendered string.
"""

import base64;
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.byllm.lib { Document, MockLLM }
import from support { document_blocks, say, user_blocks }


glob PDF: bytes = b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n";

def _pdf_data_url(raw: bytes) -> str {
    return "data:application/pdf;base64," + base64.b64encode(raw).decode("utf-8");
}

def _write(name: str, raw: bytes) -> str {
    path = os.path.join(tempfile.mkdtemp(prefix="doc-"), name);
    with open(path, "wb") as f {
        f.write(raw);
    }
    return path;
}


test "every accepted document source becomes the expected file block" {
    url = _pdf_data_url(PDF);
    named = _write("brief.pdf", PDF);

    # (label, what the caller hands to Document(), filename=, the block's `file`).
    # The content decides, not the extension, and bytes before the header are dropped.
    rows = [
        ("path", named, None, {"file_data": url, "filename": "brief.pdf"}),
        ("PathLike", Path(named), None, {"file_data": url, "filename": "brief.pdf"}),
        (
            "explicit name over the path's",
            _write("tmp_1234.pdf", PDF),
            "Q3 brief.pdf",
            {"file_data": url, "filename": "Q3 brief.pdf"}
        ),
        (
            "path with no extension",
            _write("brief", PDF),
            None,
            {"file_data": url, "filename": "brief"}
        ),
        ("bytes carry no name", PDF, None, {"file_data": url}),
        (
            "bytes with a name",
            PDF,
            "spec.pdf",
            {"file_data": url, "filename": "spec.pdf"}
        ),
        ("bytearray", bytearray(PDF), None, {"file_data": url}),
        ("memoryview", memoryview(PDF), None, {"file_data": url}),
        ("a newline before the header", b"\n" + PDF, None, {"file_data": url}),
        ("a BOM before the header", b"\xef\xbb\xbf" + PDF, None, {"file_data": url}),
        ("the header at byte 1000", b"x" * 1000 + PDF, None, {"file_data": url})
    ];
    for (label, source, filename, expected) in rows {
        assert Document(source, filename=filename).to_dict()
            == [{"type": "file", "file": expected}] , f"{label}: got {Document(
            source, filename=filename
        ).to_dict()}";
    }

    llm = MockLLM(outputs=[say("PINEAPPLE")]);

    def read_secret(brief: Document) -> str by llm();

    assert read_secret(Document(named)) == "PINEAPPLE";
    assert document_blocks(llm)
        == [{"type": "file", "file": {"file_data": url, "filename": "brief.pdf"}}] , f"got {user_blocks(
        llm
    )}";
    assert user_blocks(llm)[0]["type"] == "text" , (
        f"the caller name introduces the argument, got {user_blocks(llm)[0]}"
    );
}


test "what is not a PDF is refused, with an error that says why" {
    absent = os.path.join(tempfile.mkdtemp(prefix="doc-"), "absent.pdf");

    # (label, input, error type, a fragment of its message)
    rows = [
        ("markdown bytes", b"# Notes\nThe secret word is MANGO.\n", ValueError, "Text"),
        (
            "a .pdf holding markdown",
            _write("notes.pdf", b"# Notes\n"),
            ValueError,
            "Text"
        ),
        ("an empty file", _write("empty.pdf", b""), ValueError, "PDF"),
        ("image bytes", b"\x89PNG\r\n\x1a\n", ValueError, "PDF"),
        ("the header at byte 1024", b"x" * 1024 + PDF, ValueError, "PDF"),
        ("a missing file", absent, ValueError, "does not exist"),
        ("an int", 42, TypeError, "Document"),
        ("None", None, TypeError, "Document"),
        ("a list", ["%PDF-"], TypeError, "Document")
    ];
    for (label, source, error, fragment) in rows {
        raised = None;
        try {
            Document(source);
        } except Exception as e {
            raised = e;
        }
        assert isinstance(raised, error) , (
            f"{label}: expected {error.__name__}, got {raised!r}"
        );
        assert fragment in str(raised) , f"{label}: got {raised}";
    }
}
