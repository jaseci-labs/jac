glob STRICT_ENV: str = "JAC_SCALE_CONFIG_STRICT";

def known_deploy_targets -> list[str];
def scale_schema_options -> dict[str, any];
def validate_scale_config(raw: dict[str, any] | None) -> list[str];
def validate_app_scale_config(raw: dict[str, any] | None, app_name: str) -> list[str];
def _declared_target_findings(raw: dict[str, any]) -> list[str];
def _scheduler_bound_findings(raw: dict[str, any]) -> list[str];
def _as_number(raw: any) -> float | None;
def scheduler_min_interval(raw: any) -> float | None;
def scheduler_job_cap(raw: any) -> int | None;
def _jobs_bound_findings(raw: dict[str, any]) -> list[str];
def jobs_concurrency(raw: any) -> int | None;
def jobs_lease_seconds(raw: any) -> float | None;
def jobs_poll_seconds(raw: any) -> float | None;
