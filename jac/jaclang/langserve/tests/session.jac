"""Provides LSP session helpers for testing."""

import os;
import subprocess;
import sys;
import from concurrent.futures { Future, ThreadPoolExecutor } 
import from threading { Event } 

import from pylsp_jsonrpc.dispatchers { MethodDispatcher } 
import from pylsp_jsonrpc.endpoint { Endpoint } 
import from pylsp_jsonrpc.streams { JsonRpcStreamReader, JsonRpcStreamWriter } 

import defaults;


with entry {
    LSP_EXIT_TIMEOUT = 5000;
    PUBLISH_DIAGNOSTICS = 'textDocument/publishDiagnostics';
    WINDOW_LOG_MESSAGE = 'window/logMessage';
    WINDOW_SHOW_MESSAGE = 'window/showMessage';
}


"""Send and Receive messages over LSP as a test LS Client."""
class LspSession (MethodDispatcher) {
    def init(self: LspSession, cwd: Any = None) {
        self.cwd = cwd if cwd else os.getcwd() ;
        self._thread_pool = ThreadPoolExecutor();
        self._sub = None;
        self._writer = None;
        self._reader = None;
        self._endpoint = None;
        self._notification_callbacks = {};
    }
    
    """Context manager entrypoint.\n\n        shell=True needed for pytest-cov to work in subprocess.\n        """
    def __enter__(self: LspSession) {
        self._sub = subprocess.Popen(
            ["jac", "run",
            os.path.join(os.path.dirname(os.path.dirname(__file__)), 'server.jac')],
            stdout=subprocess.PIPE,
            stdin=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            bufsize=0,
            cwd=self.cwd,
            env=os.environ,
            shell=('WITH_COVERAGE' in os.environ)
        );
        self._writer = JsonRpcStreamWriter(os.fdopen(self._sub.stdin.fileno(), 'wb'));
        self._reader = JsonRpcStreamReader(os.fdopen(self._sub.stdout.fileno(), 'rb'));
        dispatcher = 
        {PUBLISH_DIAGNOSTICS : self._publish_diagnostics , WINDOW_SHOW_MESSAGE : self._window_show_message , WINDOW_LOG_MESSAGE : self._window_log_message };
        self._endpoint = Endpoint(dispatcher, self._writer.write);
        self._thread_pool.submit(self._reader.listen, self._endpoint.consume);
        return self;
    }
    
    def __exit__(self: LspSession, typ: Any, value: Any, _tb: Any) {
        self.shutdown(True);
        try {
            self._sub.terminate();
        } except Exception as e {
            
        }
        
        self._endpoint.shutdown();
        self._thread_pool.shutdown();
    }
    
    """Sends the initialize request to LSP server."""
    def initialize(
        self: LspSession,
        initialize_params: Any = None,
        process_server_capabilities: Any = None
    ) {
        server_initialized = Event();
        def _after_initialize(fut: Any) {
            if process_server_capabilities {
                process_server_capabilities(fut.result());
            }
            self.initialized();
            server_initialized.set();
        }
        self._send_request(
            'initialize',
            params=initialize_params
            if (initialize_params is not None)
            else defaults.VSCODE_DEFAULT_INITIALIZE
            ,
            handle_response=_after_initialize
        );
        server_initialized.wait();
    }
    
    """Sends the initialized notification to LSP server."""
    def initialized(self: LspSession, initialized_params: Any = None) {
        if (initialized_params is None) {
            initialized_params = {};
        }
        self._endpoint.notify('initialized', initialized_params);
    }
    
    """Sends the shutdown request to LSP server."""
    def shutdown(
        self: LspSession,
        should_exit: Any,
        exit_timeout: Any = LSP_EXIT_TIMEOUT
    ) {
        def _after_shutdown(_: Any) {
            if should_exit {
                self.exit_lsp(exit_timeout);
            }
        }
        self._send_request('shutdown', handle_response=_after_shutdown);
    }
    
    """Handles LSP server process exit."""
    def exit_lsp(self: LspSession, exit_timeout: Any = LSP_EXIT_TIMEOUT) {
        self._endpoint.notify('exit');
        assert (self._sub.wait(exit_timeout) == 0) ;
    }
    
    """Sends text document completion request to LSP server."""
    def text_document_completion(self: LspSession, completion_params: Any) {
        fut = self._send_request('textDocument/completion', params=completion_params);
        return fut.result();
    }
    
    """Sends text document rename request to LSP server."""
    def text_document_rename(self: LspSession, rename_params: Any) {
        fut = self._send_request('textDocument/rename', params=rename_params);
        return fut.result();
    }
    
    """Sends text document code action request to LSP server."""
    def text_document_code_action(self: LspSession, code_action_params: Any) {
        fut = self._send_request('textDocument/codeAction', params=code_action_params);
        return fut.result();
    }
    
    """Sends text document hover request to LSP server."""
    def text_document_hover(self: LspSession, hover_params: Any) {
        fut = self._send_request('textDocument/hover', params=hover_params);
        return fut.result();
    }
    
    """Sends text document formatting request to LSP server."""
    def text_document_formatting(self: LspSession, formatting_params: Any) {
        fut = self._send_request('textDocument/formatting', params=formatting_params);
        return fut.result();
    }
    
    """Sends text document hover request to LSP server."""
    def text_document_signature_help(self: LspSession, signature_help_params: Any) {
        fut = self._send_request(
            'textDocument/signatureHelp',
            params=signature_help_params
        );
        return fut.result();
    }
    
    """Sends text document declaration request to LSP server."""
    def text_document_declaration(self: LspSession, declaration_params: Any) {
        fut = self._send_request('textDocument/declaration', params=declaration_params);
        return fut.result();
    }
    
    """Sends text document definition request to LSP server."""
    def text_document_definition(self: LspSession, definition_params: Any) {
        fut = self._send_request('textDocument/definition', params=definition_params);
        return fut.result();
    }
    
    """Sends text document symbol request to LSP server."""
    def text_document_symbol(self: LspSession, document_symbol_params: Any) {
        fut = self._send_request(
            'textDocument/documentSymbol',
            params=document_symbol_params
        );
        return fut.result();
    }
    
    """Sends text document highlight request to LSP server."""
    def text_document_highlight(self: LspSession, document_highlight_params: Any) {
        fut = self._send_request(
            'textDocument/documentHighlight',
            params=document_highlight_params
        );
        return fut.result();
    }
    
    """Sends text document references request to LSP server."""
    def text_document_references(self: LspSession, references_params: Any) {
        fut = self._send_request('textDocument/references', params=references_params);
        return fut.result();
    }
    
    """Sends workspace symbol request to LSP server."""
    def workspace_symbol(self: LspSession, workspace_symbol_params: Any) {
        fut = self._send_request('workspace/symbol', params=workspace_symbol_params);
        return fut.result();
    }
    
    """Sends completion item resolve request to LSP server."""
    def completion_item_resolve(self: LspSession, resolve_params: Any) {
        fut = self._send_request('completionItem/resolve', params=resolve_params);
        return fut.result();
    }
    
    """Sends did change notification to LSP Server."""
    def notify_did_change(self: LspSession, did_change_params: Any) {
        self._send_notification('textDocument/didChange', params=did_change_params);
    }
    
    """Sends did save notification to LSP Server."""
    def notify_did_save(self: LspSession, did_save_params: Any) {
        self._send_notification('textDocument/didSave', params=did_save_params);
    }
    
    """Sends did open notification to LSP Server."""
    def notify_did_open(self: LspSession, did_open_params: Any) {
        self._send_notification('textDocument/didOpen', params=did_open_params);
    }
    
    """Set custom LS notification handler."""
    def set_notification_callback(
        self: LspSession,
        notification_name: Any,
        callback: Any
    ) {
        self._notification_callbacks[notification_name] = callback;
    }
    
    """Gets callback if set or default callback for a given LS notification."""
    def get_notification_callback(self: LspSession, notification_name: Any) {
        try {
            return self._notification_callbacks[notification_name];
        } except KeyError {
            def _default_handler(_params: Any) -> None {}
            return _default_handler;
        }
        
    }
    
    """Internal handler for text document publish diagnostics."""
    def _publish_diagnostics(self: LspSession, publish_diagnostics_params: Any) {
        return self._handle_notification(
            PUBLISH_DIAGNOSTICS,
            publish_diagnostics_params
        );
    }
    
    """Internal handler for window log message."""
    def _window_log_message(self: LspSession, window_log_message_params: Any) {
        return self._handle_notification(WINDOW_LOG_MESSAGE, window_log_message_params);
    }
    
    """Internal handler for window show message."""
    def _window_show_message(self: LspSession, window_show_message_params: Any) {
        return self._handle_notification(
            WINDOW_SHOW_MESSAGE,
            window_show_message_params
        );
    }
    
    """Internal handler for notifications."""
    def _handle_notification(self: LspSession, notification_name: Any, params: Any) {
        fut = Future();
        def _handler() {
            callback = self.get_notification_callback(notification_name);
            callback(params);
            fut.set_result(None);
        }
        self._thread_pool.submit(_handler);
        return fut;
    }
    
    """Sends {name} request to the LSP server."""
    def _send_request(
        self: LspSession,
        name: Any,
        params: Any = None,
        handle_response: Any = lambda  f: Any: f.done()
    ) {
        fut = self._endpoint.request(name, params);
        fut.add_done_callback(handle_response);
        return fut;
    }
    
    """Sends {name} notification to the LSP server."""
    def _send_notification(self: LspSession, name: Any, params: Any = None) {
        self._endpoint.notify(name, params);
    }
}
