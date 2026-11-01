glob:priv EPSILON: float = 1e-8;

glob _NO_MIN: float = -1e308,
     _NO_MAX: float = 1e308;


obj PartitionRequest {
    has span: int,
        targets: list[float],
        fixed: list[bool] = [],
        minimums: list[float] = [],
        maximums: list[float] = [];
}


obj QuantizeResult {
    has ok: bool = True,
        sizes: list[int] = [],
        message: str = "",
        index: int = -1;
}


def _floor(value: float) -> int;


def _ceil(value: float) -> int;


def snap_edge(value: float) -> int;


def snap_edge_group(values: list[float]) -> list[int];


def _quant_fail(message: str, index: int) -> QuantizeResult;


def _bounds_ok_shape(req: PartitionRequest) -> bool;


def quantize_partition(req: PartitionRequest) -> QuantizeResult;


def _apply_bounds(
    req: PartitionRequest,
    sizes: list[int],
    flexible: list[int],
    remainders: list[float],
) -> QuantizeResult;
