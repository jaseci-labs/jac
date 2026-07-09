"""Aggregate of the embed TUI's mutable singletons.

One TuiRuntime instance (built in host_embed) owns everything the loop
mutates: UI state, the diff painter, the Python-embed transport, the
outbound command queue, and the paint scratch buffer.
"""

import from .state { TuiState }
import from .diff { DiffEngine, PaintBuf }
import from .transport { EmbedPyTransport, CmdQueue }

"""Owns all mutable TUI singletons; passed by reference through the loop."""
obj TuiRuntime {
    # `transport: EmbedPyTransport = EmbedPyTransport()` is a FROZEN literal
    # (arch-verified): keep the field typed as the EmbedPyTransport subclass
    # with an inline constructor default -- do not widen to TtyFdTransport
    # or hoist the construction.
    has state: TuiState = TuiState(),
        diff: DiffEngine = DiffEngine(),
        transport: EmbedPyTransport = EmbedPyTransport(),
        cmd_queue: CmdQueue = CmdQueue(),
        paint_buf: PaintBuf = PaintBuf();
}
