"""Real JSON-RPC sessions exercise intake, revision publication and cancellation."""
import time;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.testing.lsp_client { LspClient }

test "stdio burst checks every document and accepts cancellation during analysis" {
    with TemporaryDirectory() as directory {
        client = LspClient(directory);
        paths: list[str] = [];
        try {
            for index in range(10) {
                source_path = Path(directory) / f'file{index}.jac';
                source = f'def value_{index} -> int {{ return {index}; }}\n';
                source_path.write_text(source);
                paths.append(str(source_path));
                client.open(str(source_path), source);
            }
            for path in paths {
                event = client.diagnostics(path, 1, timeout=60.0);
                assert event.body['params']['diagnostics'] == [];
            }
            target = paths[0];
            source = ''.join(
                f'def value_{index} -> int {{ return {index}; }}\n'
                for index in range(500)
            );
            client.change(target, source, 2);
            params = {
                'textDocument': {'uri': Path(target).as_uri()},
                'position': {'line': 0, 'character': 6}
            };
            request = client.send_request('textDocument/completion', params);
            started = time.monotonic();
            client.notify('$/cancelRequest', {'id': request});
            response = client.response(request, timeout=5.0);
            assert response.body.get('error', {}).get('code') == -32800;
            assert response.timestamp - started < 5.0;
            client.change(target, 'def latest -> int { return 42; }\n', 3);
            client.diagnostics(target, 3, timeout=60.0);
            outline = client.request(
                'textDocument/documentSymbol',
                {'textDocument': {'uri': Path(target).as_uri()}}
            );
            assert any(
                symbol.get('name') == 'latest' for symbol in outline.body['result']
            );
            count = sum(
                event.body.get('id') == request and 'method' not in event.body
                for event in client.events
            );
            assert count == 1 , 'a cancelled request must receive exactly one response';
        } finally {
            client.close();
        }
    }
}

test "stdio dependency diagnostics recover through repeated unsaved changes" {
    with TemporaryDirectory() as directory {
        library = Path(directory) / 'lib.jac';
        consumer = Path(directory) / 'app.jac';
        good = 'obj Foo { has x: int; }\n';
        bad = 'obj Foo { has y: str; }\n';
        app_source = 'import from .lib { Foo }\nwith entry { f = Foo(x=1); print(f.x); }\n';
        library.write_text(good);
        consumer.write_text(app_source);
        client = LspClient(directory);
        try {
            client.open(str(library), good);
            client.open(str(consumer), app_source);
            client.diagnostics(str(consumer), 1, timeout=60.0);
            for version in range(2, 6) {
                broken = version % 2 == 0;
                started = time.monotonic();
                client.change(str(library), bad if broken else good, version);
                uri = consumer.as_uri();
                event = client.until(
                    lambda (body: dict) -> bool { return body.get('method')
                        == 'textDocument/publishDiagnostics'
                        and body.get('params', {}).get('uri') == uri; },
                    since=started,
                    timeout=60.0
                );
                errors = [
                    item
                    for item in event.body['params']['diagnostics']
                    if item.get('severity') == 1
                ];
                assert bool(errors) == broken;
                assert library.read_text() == good , 'edits must remain unsaved';
            }
        } finally {
            client.close();
        }
    }
}

test "watched closed dependencies invalidate consumers and recover after deletion" {
    with TemporaryDirectory() as directory {
        library = Path(directory) / 'lib.jac';
        consumer = Path(directory) / 'app.jac';
        good = 'obj Foo { has x: int; }\n';
        bad = 'obj Foo { has y: str; }\n';
        source = 'import from .lib { Foo }\nwith entry { f = Foo(x=1); print(f.x); }\n';
        library.write_text(good);
        consumer.write_text(source);
        client = LspClient(directory);
        try {
            registration = client.until(
                lambda (body: dict) -> bool { return body.get('method')
                    == 'client/registerCapability'; }
            );
            assert registration.body['params']['registrations'][0]['method']
                == 'workspace/didChangeWatchedFiles';
            client.open(str(consumer), source);
            assert client.diagnostics(str(consumer), 1, timeout=60.0).body['params'][
                'diagnostics'
            ]
                == [];
            for step in range(4) {
                started = time.monotonic();
                change_type = 2;
                if step == 2 {
                    library.unlink();
                    change_type = 3;
                } else {
                    library.write_text(bad if step == 0 else good);
                    change_type = 1 if step == 3 else 2;
                }
                client.notify(
                    'workspace/didChangeWatchedFiles',
                    {'changes': [{'uri': library.as_uri(), 'type': change_type}]}
                );
                event = client.until(
                    lambda (body: dict) -> bool { return body.get('method')
                        == 'textDocument/publishDiagnostics'
                        and body.get('params', {}).get('uri') == consumer.as_uri(); },
                    since=started,
                    timeout=60.0
                );
                errors = [
                    item
                    for item in event.body['params']['diagnostics']
                    if item.get('severity') == 1
                ];
                assert bool(errors) == (step in (0, 2));
            }
        } finally {
            client.close();
        }
    }
}

test "creating a previously missing dependency refreshes its open consumer" {
    with TemporaryDirectory() as directory {
        library = Path(directory) / 'new_library.jac';
        consumer = Path(directory) / 'app.jac';
        source = 'import from .new_library { answer }\ndef run -> int { return answer(); }\n';
        consumer.write_text(source);
        client = LspClient(directory);
        try {
            client.open(str(consumer), source);
            first = client.diagnostics(str(consumer), 1, timeout=60.0);
            assert any(
                item.get('severity') == 1
                for item in first.body['params']['diagnostics']
            );
            started = time.monotonic();
            library.write_text('def answer -> int { return 42; }\n');
            client.notify(
                'workspace/didChangeWatchedFiles',
                {'changes': [{'uri': library.as_uri(), 'type': 1}]}
            );
            recovered = client.until(
                lambda (body: dict) -> bool { return body.get('method')
                    == 'textDocument/publishDiagnostics'
                    and body.get('params', {}).get('uri') == consumer.as_uri(); },
                since=started,
                timeout=60.0
            );
            assert not recovered.body['params']['diagnostics'];
        } finally {
            client.close();
        }
    }
}
