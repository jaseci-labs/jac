import time;
import from contextlib { contextmanager }
import from contextvars { ContextVar }

glob SHOWN_FROM_SECONDS: float = 0.1,
     _recording: ContextVar[list[tuple[str, float]] | None] = ContextVar(
         'jac_build_stages', `default=None
     );

@contextmanager
def record_stages -> Iterator[list[tuple[str, float]]];

@contextmanager
def stage(done: str) -> Iterator[None];
