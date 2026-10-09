import logging;
import from contextvars { Token }
import from types { TracebackType }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.runtime { JacRuntime }

glob logger: logging.Logger = logging.getLogger('jaclang.serve');


obj RequestScope {
    has context: ExecutionContext,
        _token: Token[(ExecutionContext | None)],
        _aborted: bool = False;

    static def open(
        base_path_dir: (str | None) = None, full_target_path: (str | None) = None
    ) -> RequestScope {
        context = JacRuntime.create_j_context(
            user_root=None,
            base_path_dir=base_path_dir,
            full_target_path=full_target_path
        );
        return RequestScope(
            context=context, _token=JacRuntime.push_request_context(context)
        );
    }

    static def current -> ExecutionContext {
        context = JacRuntime.request_context();
        if context is None {
            raise RuntimeError(
                'No request scope is open. A walker or function is executed '
                'inside RequestScope.open(), which gives the call a context and '
                'session of its own; the process-global context is not a '
                'request context.'
            );
        }
        return context;
    }

    def abort {
        self._aborted = True;
        self._discard();
    }

    def _discard {
        self.context.mem.abort();
        self.context.pending_effects.clear();
    }

    def close {
        try {
            if self._aborted {
                self._discard();
            }
            self.context.close();
        } except Exception as e {
            logger.warning(f"Failed to close request context: {e}", exc_info=True);
        } finally {
            JacRuntime.reset_request_context(self._token);
        }
    }

    def __enter__ -> ExecutionContext {
        return self.context;
    }

    def __exit__(
        exc_type: (type[BaseException] | None),
        exc: (BaseException | None),
        tb: (TracebackType | None)
    ) -> bool {
        self.close();
        return False;
    }
}
