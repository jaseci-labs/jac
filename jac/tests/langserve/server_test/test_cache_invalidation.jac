"""Cross-file cache invalidation tests for the Jac language server.

Two failure modes that surfaced when an open file's diagnostics did not
refresh after a dependency changed:

  1. Disk edit of an imported module is not seen on subsequent did_save
     because `JacProgram.mod.hub` returns the cached IR forever.
  2. A consumer file's diagnostics do not auto-refresh when its imported
     dependency receives an LSP event, because nothing tracks reverse
     dependents.
"""

import asyncio;
import os;
import shutil;
import tempfile;

import from pathlib { Path }

import from jaclang.lsp.types {
    DidChangeTextDocumentParams,
    DidOpenTextDocumentParams,
    DidSaveTextDocumentParams,
    TextDocumentIdentifier,
    TextDocumentItem,
    VersionedTextDocumentIdentifier
}

import from jaclang.langserve.engine { JacLangServer }
import from jaclang.langserve.server { did_change, did_open, did_save }
import from jaclang.lsp.server { Workspace }
import from jaclang.lsp.uris { from_fs_path }

# Library and consumer source pairs. APP_SRC instantiates Foo with field
# `x`; LIB_BREAK renames the field to `y` so any cached LIB_OK lets APP_SRC
# pass while a fresh recompile against LIB_BREAK rejects it.
glob LIB_OK = "obj Foo { has x: int; }\n",
     LIB_BREAK = "obj Foo { has y: str; }\n",
     APP_SRC = (
         "import from .lib { Foo }\n"
         "with entry {\n"
         "    f = Foo(x=1);\n"
         "    print(f.x);\n"
         "}\n"
     );

"""Force the file's mtime to advance past any cache fingerprint, with no real-time wait."""
def _bump_mtime(path: str) {
    st = os.stat(path);
    new_t = st.st_mtime + 5.0;
    os.utime(path, (new_t, new_t));
}

"""Count error-severity diagnostics for a URI on the language server."""
def _err_count(ls: JacLangServer, uri: str) -> int {
    diags = ls.diagnostics.get(uri, []);
    n = 0;
    for d in diags {
        if d?.severity == 1 {
            n += 1;
        }
    }
    return n;
}

test "stale dep refreshed on consumer save" {
    proj = tempfile.mkdtemp(prefix="jac_lsp_invalidation_");
    lib_path = os.path.join(proj, "lib.jac");
    app_path = os.path.join(proj, "app.jac");
    Path(lib_path).write_text(LIB_OK);
    Path(app_path).write_text(APP_SRC);

    ls = JacLangServer();
    ls.lsp._workspace = Workspace(root_uri=(from_fs_path(proj) or ""));
    app_uri = from_fs_path(app_path) or "";

    try {
        # Phase 1: open the consumer with the dep in OK shape -- baseline 0 errors.
        # Real LSP flow populates the workspace before invoking the open
        # handler; mirror that so the server treats the doc as open.
        app_doc = TextDocumentItem(
            uri=app_uri, language_id="jac", version=1, text=APP_SRC
        );
        ls.workspace.put_text_document(app_doc);
        asyncio.run(did_open(ls, DidOpenTextDocumentParams(text_document=app_doc)));
        ls.wait_till_idle_sync(app_uri);
        assert _err_count(ls, app_uri) == 0 , (
            "baseline: app should have 0 errors when lib defines field x"
        );

        # Phase 2: rewrite the dep on disk in a way that breaks the consumer
        # (Foo.x replaced by Foo.y), and bump its mtime so any mtime-based
        # freshness check definitely sees the change.
        Path(lib_path).write_text(LIB_BREAK);
        _bump_mtime(lib_path);

        # Phase 3: did_save the consumer. After Fix 1 (mtime-validated hub
        # lookups), the cached lib IR is rejected and a fresh recompile
        # surfaces the broken usage.
        asyncio.run(
            did_save(
                ls,
                DidSaveTextDocumentParams(
                    text_document=TextDocumentIdentifier(uri=app_uri), text=APP_SRC
                )
            )
        );
        ls.wait_till_idle_sync(app_uri);
        assert _err_count(ls, app_uri) >= 1 , (
            "stale dep cache: app must show errors after dep changed on disk"
        );
    } finally {
        ls.shutdown();
        shutil.rmtree(proj, ignore_errors=True);
    }
}

test "consumer auto-rechecked when dep receives did_change" {
    proj = tempfile.mkdtemp(prefix="jac_lsp_invalidation_");
    lib_path = os.path.join(proj, "lib.jac");
    app_path = os.path.join(proj, "app.jac");
    Path(lib_path).write_text(LIB_OK);
    Path(app_path).write_text(APP_SRC);

    ls = JacLangServer();
    ls.lsp._workspace = Workspace(root_uri=(from_fs_path(proj) or ""));
    lib_uri = from_fs_path(lib_path) or "";
    app_uri = from_fs_path(app_path) or "";

    try {
        # Open both files, baseline clean. The real LSP dispatcher puts the
        # document into the workspace before invoking did_open; mirror that
        # so the server treats both files as open.
        lib_doc = TextDocumentItem(
            uri=lib_uri, language_id="jac", version=1, text=LIB_OK
        );
        app_doc = TextDocumentItem(
            uri=app_uri, language_id="jac", version=1, text=APP_SRC
        );
        ls.workspace.put_text_document(lib_doc);
        ls.workspace.put_text_document(app_doc);
        asyncio.run(did_open(ls, DidOpenTextDocumentParams(text_document=lib_doc)));
        ls.wait_till_idle_sync(lib_uri);
        asyncio.run(did_open(ls, DidOpenTextDocumentParams(text_document=app_doc)));
        ls.wait_till_idle_sync(app_uri);
        assert _err_count(ls, app_uri) == 0;

        # Change the dep through did_change. No event for the consumer.
        ls.workspace.put_text_document(
            TextDocumentItem(uri=lib_uri, language_id="jac", version=2, text=LIB_BREAK)
        );
        Path(lib_path).write_text(LIB_BREAK);
        _bump_mtime(lib_path);
        asyncio.run(
            did_change(
                ls,
                DidChangeTextDocumentParams(
                    text_document=VersionedTextDocumentIdentifier(
                        uri=lib_uri, version=2
                    ),
                    content_changes=[{"text": LIB_BREAK}]
                )
            )
        );
        # After Fix 2 (reverse-dep enqueue) the dep's check pushes the
        # consumer into dirty_files; wait_till_idle_sync extends until the
        # whole queue drains.
        ls.wait_till_idle_sync(lib_uri);

        assert _err_count(ls, app_uri) >= 1 , (
            "rdep fanout: app must auto-recheck after its dep changed"
        );
    } finally {
        ls.shutdown();
        shutil.rmtree(proj, ignore_errors=True);
    }
}
