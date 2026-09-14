import from io { BytesIO }
import from threading { Event, Thread }
import from unittest.mock { patch }
import from jaclang.lsp.protocol.server { LanguageServer, Request }

test "a response serialization failure returns an error instead of losing the request" {
    server = LanguageServer();
    output = BytesIO();
    server._transport_writer = output;
    server._features['probe'] = lambda (ls: any, params: any) -> any { return object(); };
    request = Request(1, 'probe', {}, server.workspace.revision);
    server._requests[1] = request;
    server._run_request(request);
    messages = BytesIO(output.getvalue());
    response = server._read_message(messages);
    assert response is not None and response['error']['code'] == -32603;
    assert request.responded and 1 not in server._requests;
    assert server._read_message(messages) is None;
}

test "cancellation remains available while a response is being prepared" {
    server = LanguageServer();
    output = BytesIO();
    server._transport_writer = output;
    server._features['probe'] = lambda (ls: any, params: any) -> any { return {
        'value': 1
    }; };
    request = Request(1, 'probe', {}, server.workspace.revision);
    server._requests[1] = request;
    preparing = Event();
    proceed = Event();
    cancelled = Event();
    convert = server.workspace.convert_positions;
    def pause(value: any, uri: str = '', to_client: bool = True) -> any {
        if to_client {
            preparing.set();
            assert proceed.wait(timeout=10);
        }
        return convert(value, uri, to_client);
    }
    def cancel {
        server._cancel_request(1);
        cancelled.set();
    }
    worker = Thread(target=server._run_request, args=(request, ));
    canceller = Thread(target=cancel);
    with patch.object(server.workspace, 'convert_positions', side_effect=pause) {
        worker.start();
        try {
            assert preparing.wait(timeout=10);
            canceller.start();
            assert cancelled.wait(timeout=5) , 'preparing a response blocked cancellation';
        } finally {
            proceed.set();
            worker.join(timeout=10);
            if canceller.ident is not None {
                canceller.join(timeout=10);
            }
        }
    }
    assert not worker.is_alive() and not canceller.is_alive();
    messages = BytesIO(output.getvalue());
    response = server._read_message(messages);
    assert response is not None and response['error']['code'] == -32800;
    assert server._read_message(messages) is None;
}
