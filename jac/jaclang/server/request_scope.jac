import logging;
import from contextvars { Token }
import from types { TracebackType }

glob logger: logging.Logger = logging.getLogger('jaclang.serve');


obj RequestScope {
    has context: ExecutionContext,
        _token: Token[(ExecutionContext | None)],
        _aborted: bool = False;

    static def open(
        base_path_dir: (str | None) = None, full_target_path: (str | None) = None
    ) -> RequestScope;

    static def current -> ExecutionContext;
    def abort;
    def _discard;
    def close;
    async def aclose;
    def __enter__ -> ExecutionContext;
    def __exit__(
        exc_type: (type[BaseException] | None),
        exc: (BaseException | None),
        tb: (TracebackType | None)
    ) -> bool;

    async def __aenter__ -> ExecutionContext;
    async def __aexit__(
        exc_type: (type[BaseException] | None),
        exc: (BaseException | None),
        tb: (TracebackType | None)
    ) -> bool;
}
