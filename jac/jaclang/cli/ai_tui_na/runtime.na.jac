import from .state { TuiState }
import from .diff { DiffEngine, PaintBuf }
import from .transport { EmbedPyTransport, CmdQueue }

obj TuiRuntime {
    has state: TuiState = TuiState(),
        diff: DiffEngine = DiffEngine(),
        transport: EmbedPyTransport = EmbedPyTransport(),
        cmd_queue: CmdQueue = CmdQueue(),
        paint_buf: PaintBuf = PaintBuf();
}
