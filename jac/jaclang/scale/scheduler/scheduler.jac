import json;
import logging;
import datetime;
import from uuid { uuid4 }
import from jaclang.comptime { fields, get_field }
import from jaclang.scale._optdeps.apscheduler {
    BackgroundScheduler,
    CronTrigger,
    ThreadPoolExecutor,
    HAS_APSCHEDULER
}
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.server.task_scheduler { Scheduler, ScheduleTrigger }
import from jaclang.server.shared_store { open_docs_store }

glob _jaclang_scale_scheduler: (JacScaleScheduler | None) = None,
     JOBS_CHANGED_CHANNEL: str = 'jac_jobs_changed',
     logger = logging.getLogger(__name__);

obj JobStore {
    def insert(job: dict) -> str;
    def find_active(
        limit: int | None = None,
        offset: int = 0,
        trigger: str | None = None,
        created_by: str | None = None
    ) -> tuple[list[dict], int];

    def find_active_one(job_id: str) -> dict | None;
    def update(job_id: str, updates: dict, where: dict | None = None) -> bool;
    def delete(job_id: str, where: dict | None = None) -> bool;
    def record_run(job_id: str, status: str, error: str | None = None) -> None;
}

obj PgJobStore(JobStore) {
    has store: any,
        _collection: str;

    def insert(job: dict) -> str;
    def find_active(
        limit: int | None = None,
        offset: int = 0,
        trigger: str | None = None,
        created_by: str | None = None
    ) -> tuple[list[dict], int];

    def find_active_one(job_id: str) -> dict | None;
    def update(job_id: str, updates: dict, where: dict | None = None) -> bool;
    def delete(job_id: str, where: dict | None = None) -> bool;
    def record_run(job_id: str, status: str, error: str | None = None) -> None;
}

obj MemoryJobStore(JobStore) {
    has _jobs: dict[str, dict] postinit;

    def postinit -> None;
    def insert(job: dict) -> str;
    def find_active(
        limit: int | None = None,
        offset: int = 0,
        trigger: str | None = None,
        created_by: str | None = None
    ) -> tuple[list[dict], int];

    def find_active_one(job_id: str) -> dict | None;
    def update(job_id: str, updates: dict, where: dict | None = None) -> bool;
    def delete(job_id: str, where: dict | None = None) -> bool;
    def record_run(job_id: str, status: str, error: str | None = None) -> None;
}

obj TriggerSpec {
    has trigger: str,
        interval: float | None = None,
        cron: str | None = None,
        date: str | None = None;

    static def validate(
        trigger: str,
        interval: float | None = None,
        cron: str | None = None,
        date: str | None = None
    ) -> TriggerSpec;

    static def from_dict(d: dict) -> TriggerSpec;
    def to_dict -> dict;
    def apscheduler_kwargs -> dict;
}

obj JacScaleScheduler {
    has _apscheduler: any | None = None,
        _system_user_id: str = '__system__',
        _store: JobStore | None = None,
        _server: any | None = None,
        _user_exists_cache: dict[str, float] postinit,
        _user_exists_ttl: float = 30.0;

    def postinit -> None;
    static def instance -> JacScaleScheduler;
    def setup(system_user_id: str, server: any | None = None) -> None;
    def start -> None;
    def stop(drain: bool = False) -> None;
    def register_dynamic_tasks_from_db -> None;
    def create_job(name: str, spec: TriggerSpec, created_by: str) -> dict;
    def list_jobs(
        limit: int | None = None,
        offset: int = 0,
        trigger: str | None = None,
        created_by: str | None = None
    ) -> tuple[list[dict], int];

    def get_job(job_id: str) -> (dict | None);
    def update_job(
        job_id: str, spec: TriggerSpec, acting_as: str | None = None
    ) -> (dict | None);

    def delete_job(job_id: str, acting_as: str | None = None) -> bool;
    def _acquire_fire_lease(job_id: str, spec: TriggerSpec) -> bool;
    def _notify_jobs_changed(job_id: str) -> None;
    def _start_jobs_listener -> None;
    def _on_jobs_changed(payload: str) -> None;
    def _execute_task(
        name: str, user_id: str, is_walker: bool, job_id: str | None = None
    ) -> None;

    def _schedule_apscheduler_job(
        job_id: str, name: str, spec: TriggerSpec, user_id: str, is_walker: bool = True
    ) -> None;

    def _record_run(job_id: str, status: str, error: str | None = None) -> None;
    def _mark_failed(job_id: str | None, reason: str) -> None;
    def _user_is_live(user_id: str) -> bool;
    def _require_store -> JobStore;
}
