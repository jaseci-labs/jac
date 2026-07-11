import from .state { TuiState }
import from .diff { DiffEngine, PaintBuf }
import from .transport { EmbedPyTransport, CmdQueue }
import from .screen { Screen }

obj TuiRuntime {
    has state: TuiState = TuiState(),
        diff: DiffEngine = DiffEngine(),
        transport: EmbedPyTransport = EmbedPyTransport(),
        cmd_queue: CmdQueue = CmdQueue(),
        paint_buf: PaintBuf = PaintBuf(),
        screen: Screen = Screen();
}
