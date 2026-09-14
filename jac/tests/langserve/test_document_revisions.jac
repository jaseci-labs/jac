"""Editor snapshots are complete revisions, including all changes in a batch."""
import from jaclang.lsp.protocol.server { Workspace, from_dict }
import from jaclang.lsp.protocol.types { TextDocumentItem, DidChangeTextDocumentParams }

test "snapshot preserves the previous text and accepts UTF16 change batches" {
    workspace = Workspace();
    uri = 'file:///snapshot.jac';
    workspace.put_text_document(
        TextDocumentItem(uri=uri, language_id='jac', version=1, text='a😀b\n')
    );
    before = workspace.snapshot();
    change = from_dict(
        {
            'textDocument': {'uri': uri, 'version': 2},
            'contentChanges': [
                {
                    'range': {
                        'start': {'line': 0, 'character': 1},
                        'end': {'line': 0, 'character': 3}
                    },
                    'text': 'x'
                },
                {
                    'range': {
                        'start': {'line': 0, 'character': 2},
                        'end': {'line': 0, 'character': 3}
                    },
                    'text': 'y'
                }
            ]
        },
        DidChangeTextDocumentParams
    );
    workspace.change_text_document(change);
    after = workspace.snapshot();
    assert before.documents[uri].source == 'a😀b\n';
    assert before.documents[uri].version == 1;
    assert after.documents[uri].source == 'axy\n';
    assert after.documents[uri].version == 2;
    assert after.revision == before.revision + 1;
    workspace.change_text_document(change);
    assert workspace.revision == after.revision;
    workspace.remove_text_document(uri);
    assert not workspace.snapshot().documents;
    assert uri in after.documents;
}

test "renaming an open document preserves its unsaved revision" {
    workspace = Workspace();
    old_uri = 'file:///before.jac';
    new_uri = 'file:///after.jac';
    workspace.put_text_document(
        TextDocumentItem(uri=old_uri, language_id='jac', version=7, text='unsaved')
    );
    before = workspace.snapshot();
    workspace.rename_text_document(old_uri, new_uri);
    after = workspace.snapshot();
    assert old_uri not in after.documents and new_uri not in before.documents;
    assert after.documents[new_uri].source == 'unsaved';
    assert after.documents[new_uri].version == 7;
    assert after.documents[new_uri].path == '/after.jac';
    assert after.revision > before.revision;
    workspace.touch();
    assert workspace.revision > after.revision;
}
