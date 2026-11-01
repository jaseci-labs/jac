glob SNAPSHOT_OPTIMIZE_BATCH_SIZE: int = 16;

obj NativeSnapshotResult {
    has path: str,
        snapshot: UnitIRSnapshot;
}

obj NativeOptimizationInput {
    has path: str,
        bitcode: bytes;
}

obj NativeOptimizedUnit {
    has path: str,
        bitcode: bytes;
}

obj NativeOptimizationBatch {
    has units: list[NativeOptimizedUnit],
        elapsed: float;
}

obj NativeSnapshotPipeline {
    has options: CompileOptions,
        snapshot_executor: any = None,
        snapshot_future: any = None,
        snapshot_path: (str | None) = None,
        optimizer_executor: any = None,
        optimizer_future: any = None,
        optimizer_paths: list[str] = [],
        pending_optimization: list[NativeOptimizationInput] = [];

    def enqueue_snapshot(path: str, ir_text: str);
    def take_snapshot(path: (str | None) = None) -> (NativeSnapshotResult | None);
    def queue_optimization(
        path: str,
        bitcode: bytes,
        on_complete: Callable[[NativeOptimizationBatch], None]
    );

    def finish_optimization(on_complete: Callable[[NativeOptimizationBatch], None]);
    def close;
    def _flush_optimization(
        force: bool, on_complete: (Callable[[NativeOptimizationBatch], None] | None)
    );

    def _await_optimization(
        on_complete: (Callable[[NativeOptimizationBatch], None] | None)
    );
}

def _snapshot_ir_text(path: str, ir_text: str) -> NativeSnapshotResult;

def _optimize_snapshot_batch(
    bitcodes: list[bytes], options: CompileOptions
) -> tuple[list[bytes], float];
