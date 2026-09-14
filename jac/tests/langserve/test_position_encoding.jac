import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.lsp.protocol.server { LanguageServer, Workspace, TextDocument }
import jaclang.lsp.protocol.types as lspt;
import from jaclang.testing.lsp_client { LspClient }

test "protocol conversion preserves cached products and handles every position encoding" {
    for (encoding, column) in [('utf-8', 6), ('utf-16', 4), ('utf-32', 3)] {
        server = LanguageServer();
        initialized = server._handle_initialize(
            {'capabilities': {'general': {'positionEncodings': [encoding]}}}
        );
        assert initialized['capabilities']['positionEncoding'] == encoding;
        workspace = server.workspace;
        uri = 'file:///tmp/encoding-main.jac';
        workspace.put_text_document(
            lspt.TextDocumentItem(uri=uri, text='a😀 value\n', version=1)
        );
        original = {
            'range': {
                'start': {'line': 0, 'character': 3},
                'end': {'line': 0, 'character': 8}
            }
        };
        converted = workspace.convert_positions(original, uri);
        assert converted['range']['start']['character'] == column;
        assert converted['range']['end']['character'] == column + 5;
        assert original['range']['start']['character'] == 3;
        assert workspace.convert_positions(converted, uri, to_client=False) == original;
        assert workspace.convert_positions({'changes': {uri: [original]}})['changes'][
            uri
        ][0]
            == converted;
        assert workspace.convert_positions({'uri': uri, ** original})['range']
            == converted['range'];
        assert workspace.encode_semantic_tokens(uri, [0, 3, 5, 1, 0])
            == [0, column, 5, 1, 0];
        document = workspace.get_text_document(uri);
        assert document._position_codec is workspace._position_codec;
        document.apply_change(
            lspt.TextDocumentContentChangeEvent_Type1(
                range=lspt.Range(lspt.Position(1, 0), lspt.Position(1, 0)),
                text='next\n'
            )
        );
        assert document.source == 'a😀 value\nnext\n';
    }
}

test "Unicode positions survive real hover definition rename and semantic token responses" {
    with TemporaryDirectory() as directory {
        path = Path(directory) / 'unicode.jac';
        source = 'glob label = "😀"; glob value = 42; with entry { print(value); }\n';
        path.write_text(source);
        client = LspClient(directory);
        try {
            client.open(str(path), source);
            assert not client.diagnostics(str(path), 1, timeout=60.0).body['params'][
                'diagnostics'
            ];
            declaration = source.index('value') + 1;
            use = source.rindex('value') + 1;
            params = {
                'textDocument': {'uri': path.as_uri()},
                'position': {'line': 0, 'character': use}
            };
            hover = client.request('textDocument/hover', params).body['result'];
            assert hover is not None;
            definition = client.request('textDocument/definition', params).body[
                'result'
            ];
            assert definition['range']['start']
                == {'line': 0, 'character': declaration};
            renamed = client.request(
                'textDocument/rename', {** params, 'newName': 'renamed'}
            ).body['result'];
            assert {
                edit['range']['start']['character']
                for edit in renamed['changes'][path.as_uri()]
            }
                == {declaration, use};
            document = {'textDocument': {'uri': path.as_uri()}};
            outline = client.request('textDocument/documentSymbol', document).body[
                'result'
            ];
            value = next(
                symbol
                for symbol in outline
                if symbol['name'] == 'value'
            );
            assert value['selectionRange']['start']['character'] == declaration;
            data = client.request('textDocument/semanticTokens/full', document).body[
                'result'
            ]['data'];
            (line, character) = (0, 0);
            starts: set[int] = set();
            for offset in range(0, len(data), 5) {
                line += data[offset];
                character = data[offset + 1]
                    if data[offset]
                    else character + data[offset + 1];
                if line == 0 and data[offset + 2] == 5 {
                    starts.add(character);
                }
            }
            assert {declaration, use} <= starts;
            assert client.request('textDocument/documentSymbol', document).body[
                'result'
            ]
                == outline;
        } finally {
            client.close();
        }
    }
}
