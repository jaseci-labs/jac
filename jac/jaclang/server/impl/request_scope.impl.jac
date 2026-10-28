impl RequestScope.open(
    base_path_dir: (str | None) = None, full_target_path: (str | None) = None
) -> RequestScope {
    context = JacRuntime.create_j_context(
        user_root=None, base_path_dir=base_path_dir, full_target_path=full_target_path
    );
    return RequestScope(
        context=context, _token=JacRuntime.push_request_context(context)
    );
}

impl RequestScope.current -> ExecutionContext {
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

impl RequestScope.abort {
    self._aborted = True;
    self._discard();
}

impl RequestScope._discard {
    self.context.mem.abort();
    self.context.pending_effects.clear();
}

impl RequestScope.close {
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

impl RequestScope.aclose {
    try {
        if self._aborted {
            self._discard();
        }
        await self.context.aclose();
    } except Exception as e {
        logger.warning(f"Failed to close request context: {e}", exc_info=True);
    } finally {
        JacRuntime.reset_request_context(self._token);
    }
}

impl RequestScope.__enter__ -> ExecutionContext {
    return self.context;
}

impl RequestScope.__exit__(
    exc_type: (type[BaseException] | None),
    exc: (BaseException | None),
    tb: (TracebackType | None)
) -> bool {
    self.close();
    return False;
}

impl RequestScope.__aenter__ -> ExecutionContext {
    return self.context;
}

impl RequestScope.__aexit__(
    exc_type: (type[BaseException] | None),
    exc: (BaseException | None),
    tb: (TracebackType | None)
) -> bool {
    await self.aclose();
    return False;
}
