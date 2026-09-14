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
