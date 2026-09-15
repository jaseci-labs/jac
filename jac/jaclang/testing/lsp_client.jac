import json;
import os;
import subprocess;
import sys;
import threading;
import time;
import tempfile;
import from typing { IO }
import from pathlib { Path }
import from jaclang.lsp.protocol.server { LanguageServer }

obj RpcEvent {
    has timestamp: float,
        body: dict;
}

obj LspClient {
    has directory: str,
        command: list[str] | None = None,
        environment: dict[str, str] | None = None,
        process: subprocess.Popen[bytes] postinit,
        transport: LanguageServer postinit,
        condition: threading.Condition postinit,
        reader: threading.Thread postinit,
        events: list[RpcEvent] = [],
        next_id: int = 0,
        reader_error: str = '',
        startup_seconds: float = 0.0,
        error_log: IO[bytes] postinit,
        closed: bool = False;

    def postinit {
        self.condition = threading.Condition();
        self.transport = LanguageServer();
        self.error_log = tempfile.TemporaryFile(mode='w+b');
        started = time.monotonic();
        try {
            self.process = subprocess.Popen(
                self.command or [sys.executable, 'lsp'],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=self.error_log,
                env={** os.environ, ** self.environment}
                    if self.environment is not None
                    else None
            );
        } except Exception {
            self.error_log.close();
            raise;
        }
        self.transport._transport_writer = self.process.stdin;
        self.reader = threading.Thread(
            target=self.receive, name='lsp-test-reader', daemon=True
        );
        try {
            self.reader.start();
            self.request(
                'initialize',
                {
                    'processId': os.getpid(),
                    'rootUri': Path(self.directory).as_uri(),
                    'capabilities': {
                        'workspace': {
                            'semanticTokens': {'refreshSupport': True},
                            'didChangeWatchedFiles': {'dynamicRegistration': True}
                        }
                    }
                },
                timeout=300.0
            );
            self.notify('initialized', {});
        } except Exception {
            self.dispose();
            raise;
        }
        self.startup_seconds = time.monotonic() - started;
    }

    def receive {
        try {
            while True {
                body = self.transport._read_message(self.process.stdout);
                if body is None {
                    break;
                }
                with self.condition {
                    self.events.append(RpcEvent(time.monotonic(), body));
                    self.condition.notify_all();
                }
                if 'method' in body and 'id' in body {
                    self.transport._write_message(
                        {'jsonrpc': '2.0', 'id': body['id'], 'result': None}
                    );
                }
            }
        } except Exception as error {
            self.reader_error = str(error);
        } finally {
            with self.condition {
                self.condition.notify_all();
            }
        }
    }

    def notify(method: str, params: dict) {
        self.transport._write_message(
            {'jsonrpc': '2.0', 'method': method, 'params': params}
        );
    }

    def send_request(method: str, params: dict) -> int {
        self.next_id += 1;
        self.transport._write_message(
            {'jsonrpc': '2.0', 'id': self.next_id, 'method': method, 'params': params}
        );
        return self.next_id;
    }

    def until(
        predicate: Callable[[dict], bool], since: float = 0.0, timeout: float = 30.0
    ) -> RpcEvent {
        deadline = time.monotonic() + timeout;
        with self.condition {
            while True {
                for event in self.events {
                    if event.timestamp >= since and predicate(event.body) {
                        return event;
                    }
                }
                if self.reader_error {
                    raise RuntimeError(self.reader_error);
                }
                if self.process.poll() is not None {
                    raise RuntimeError(
                        f'Language server exited: {self.process.returncode}\n{self.errors()}'
                    );
                }
                remaining = deadline - time.monotonic();
                if remaining <= 0 {
                    raise TimeoutError(
                        f'Language server response timed out\n{self.errors()}'
                    );
                }
                self.condition.`wait(timeout=min(remaining, 0.5));
            }
        }
    }

    def response(message_id: int, timeout: float = 30.0) -> RpcEvent {
        return self.until(
            lambda (body: dict) -> bool { return body.get('id') == message_id
                and 'method' not in body; },
            timeout=timeout
        );
    }

    def request(method: str, params: dict, timeout: float = 30.0) -> RpcEvent {
        event = self.response(self.send_request(method, params), timeout);
        if 'error' in event.body {
            raise RuntimeError(json.dumps(event.body['error']));
        }
        return event;
    }

    def open(path: str, source: str, version: int = 1) {
        self.notify(
            'textDocument/didOpen',
            {
                'textDocument': {
                    'uri': Path(path).as_uri(),
                    'languageId': 'jac',
                    'version': version,
                    'text': source
                }
            }
        );
    }

    def change(path: str, source: str, version: int) {
        self.notify(
            'textDocument/didChange',
            {
                'textDocument': {'uri': Path(path).as_uri(), 'version': version},
                'contentChanges': [{'text': source}]
            }
        );
    }

    def diagnostics(
        path: str,
        version: int,
        timeout: float = 30.0,
        since: float = 0.0,
        allow_unversioned: bool = False
    ) -> RpcEvent {
        uri = Path(path).as_uri();
        return self.until(
            lambda (body: dict) -> bool {
                params = body.get('params', {});
                return body.get('method') == 'textDocument/publishDiagnostics'
                    and params.get('uri') == uri
                    and (
                        params.get('version') == version
                        or (allow_unversioned and params.get('version') is None)
                    );
            },
            since=since,
            timeout=timeout
        );
    }

    def rss_mib(peak: bool = False) -> float | None {
        status = Path(f'/proc/{self.process.pid}/status');
        if not status.is_file() {
            return None;
        }
        for line in status.read_text().splitlines() {
            if line.startswith('VmHWM:' if peak else 'VmRSS:') {
                return float(line.split()[1]) / 1024.0;
            }
        }
        return None;
    }

    def close {
        if self.closed {
            return;
        }
        try {
            self.request('shutdown', {}, timeout=15.0);
            self.notify('exit', {});
            self.process.`wait(timeout=10.0);
        } finally {
            self.dispose();
        }
    }

    def dispose {
        if self.closed {
            return;
        }
        self.closed = True;
        if self.process.poll() is None {
            self.process.kill();
            self.process.`wait();
        }
        if self.reader.ident is not None {
            self.reader.join(timeout=5.0);
        }
        if self.process.stdin is not None {
            self.process.stdin.close();
        }
        if self.process.stdout is not None {
            self.process.stdout.close();
        }
        self.error_log.close();
    }

    def discard_before(timestamp: float) {
        with self.condition {
            self.events[:] = [
                event
                for event in self.events
                if event.timestamp >= timestamp
            ];
        }
    }

    def errors -> str {
        self.error_log.seek(0, os.SEEK_END);
        self.error_log.seek(max(0, self.error_log.tell() - 8000));
        return self.error_log.read().decode('utf-8', errors='replace');
    }
}
