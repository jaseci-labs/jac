# Host runtime bundle. Embed/session live here; Screen/Diff stay for paint path.

import from .state { TuiState }
import from .diff { DiffEngine, PaintBuf }
import from .transport { EmbedPyTransport, CmdQueue }
import from .screen { Screen }
import from .embed_session_client { EmbedSessionClient }
import from .embed_runtime { EmbedRuntime }
import from .tui { Tui }

obj TuiRuntime {
    has state: TuiState = TuiState(),
        diff: DiffEngine = DiffEngine(),
        transport: EmbedPyTransport = EmbedPyTransport(),
        cmd_queue: CmdQueue = CmdQueue(),
        paint_buf: PaintBuf = PaintBuf(),
        screen: Screen = Screen(),
        session: EmbedSessionClient = EmbedSessionClient(),
        embed: EmbedRuntime = EmbedRuntime(),
        tui: Tui = Tui();
}
