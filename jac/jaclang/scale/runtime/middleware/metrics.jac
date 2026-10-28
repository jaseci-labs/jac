def build_gateway_metrics(
    namespace: str = "jaclang_scale", histogram_buckets: list[float] | None = None
) -> tuple[any, any, any];

def classify_outcome(status_code: int) -> str;

def render_metrics(registry: any) -> tuple[bytes, str];
