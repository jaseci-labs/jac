import concurrent.futures;
import os;
import time;

impl NativeSnapshotPipeline.enqueue_snapshot(path: str, ir_text: str) {
    if self.snapshot_future is not None {
        raise RuntimeError("previous native IR snapshot was not collected");
    }
    if self.snapshot_executor is None {
        self.snapshot_executor = concurrent.futures.ThreadPoolExecutor(max_workers=1);
    }
    self.snapshot_path = path;
    self.snapshot_future = self.snapshot_executor.submit(
        _snapshot_ir_text, path, ir_text
    );
}

impl NativeSnapshotPipeline.take_snapshot(
    path: (str | None) = None
) -> (NativeSnapshotResult | None) {
    if self.snapshot_future is None
        or self.snapshot_path is None
        or (path is not None and self.snapshot_path != os.path.realpath(path)) {
        return None;
    }
    future = self.snapshot_future;
    resolved = self.snapshot_path;
    self.snapshot_future = None;
    self.snapshot_path = None;
    (resolved, bitcode, defined, declared, function_counts) = future.result();
    return NativeSnapshotResult(
        path=resolved,
        snapshot=UnitIRSnapshot(
            bitcode=bitcode,
            defined=defined,
            declared=declared,
            function_counts=function_counts
        )
    );
}

impl NativeSnapshotPipeline.queue_optimization(
    path: str, bitcode: bytes, on_complete: Callable[[NativeOptimizationBatch], None]
) {
    self.pending_optimization.append(
        NativeOptimizationInput(path=path, bitcode=bitcode)
    );
    if len(self.pending_optimization) >= SNAPSHOT_OPTIMIZE_BATCH_SIZE {
        self._flush_optimization(False, on_complete);
    }
}

impl NativeSnapshotPipeline.finish_optimization(
    on_complete: Callable[[NativeOptimizationBatch], None]
) {
    self._flush_optimization(True, on_complete);
    self._await_optimization(on_complete);
}

impl NativeSnapshotPipeline._flush_optimization(
    force: bool, on_complete: (Callable[[NativeOptimizationBatch], None] | None)
) {
    if not self.pending_optimization
        or (
            not force and len(self.pending_optimization) < SNAPSHOT_OPTIMIZE_BATCH_SIZE
        ) {
        return;
    }
    self._await_optimization(on_complete);
    if self.optimizer_executor is None {
        self.optimizer_executor = concurrent.futures.ThreadPoolExecutor(max_workers=1);
    }
    inputs = self.pending_optimization;
    self.optimizer_paths = [item.path for item in inputs];
    bitcodes = [item.bitcode for item in inputs];
    options = self.options.clone_for_native_import();
    future = self.optimizer_executor.submit(
        _optimize_snapshot_batch, bitcodes, options
    );
    self.pending_optimization = [];
    self.optimizer_future = future;
}

impl NativeSnapshotPipeline._await_optimization(
    on_complete: (Callable[[NativeOptimizationBatch], None] | None)
) {
    if self.optimizer_future is None {
        return;
    }
    future = self.optimizer_future;
    self.optimizer_future = None;
    (bitcodes, elapsed) = future.result();
    paths = self.optimizer_paths;
    self.optimizer_paths = [];
    batch = NativeOptimizationBatch(
        units=[
            NativeOptimizedUnit(path=path, bitcode=bitcode)
            for (path, bitcode) in zip(paths, bitcodes)
        ],
        elapsed=elapsed
    );
    if on_complete is not None {
        on_complete(batch);
    }
}

impl NativeSnapshotPipeline.close {
    failure: (Exception | None) = None;
    try {
        self.take_snapshot();
    } except Exception as err {
        failure = err;
    }
    try {
        self._await_optimization(None);
    } except Exception as err {
        if failure is None {
            failure = err;
        }
    }
    if self.snapshot_executor is not None {
        executor = self.snapshot_executor;
        self.snapshot_executor = None;
        try {
            executor.shutdown(True);
        } except Exception as err {
            if failure is None {
                failure = err;
            }
        }
    }
    if self.optimizer_executor is not None {
        executor = self.optimizer_executor;
        self.optimizer_executor = None;
        try {
            executor.shutdown(True);
        } except Exception as err {
            if failure is None {
                failure = err;
            }
        }
    }
    self.snapshot_future = None;
    self.snapshot_path = None;
    self.optimizer_future = None;
    self.optimizer_paths.clear();
    self.pending_optimization.clear();
    if failure is not None {
        raise failure;
    }
}

impl _snapshot_ir_text(
    path: str, ir_text: str
) -> tuple[str, bytes, set[str], set[str], tuple[int, int]] {
    (bitcode, defined, declared, function_counts) = unit_snapshot_text_values(ir_text);
    return (path, bitcode, defined, declared, function_counts);
}

impl _optimize_snapshot_batch(
    bitcodes: list[bytes], options: CompileOptions
) -> tuple[list[bytes], float] {
    started = time.perf_counter();
    optimized = optimize_unit_bitcodes(bitcodes, options, int(options.opt_level or 0));
    return (optimized, time.perf_counter() - started);
}
