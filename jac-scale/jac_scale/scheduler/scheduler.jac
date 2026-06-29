import logging;
import datetime;
import from typing { Any }
import from uuid { uuid4 }
import from jac_scale._optdeps.apscheduler {
    BackgroundScheduler,
    CronTrigger,
    ThreadPoolExecutor,
    HAS_APSCHEDULER
}
import from jac_scale.config.config_loader { get_scale_config }
import from jaclang.runtimelib.scheduler { Scheduler, ScheduleTrigger }
import from jac_scale.persistence.db { get_mongo_client }
import from jac_scale.persistence.mongo_db { MongoDb }

glob _jac_scale_scheduler: (JacScaleScheduler | None) = None,
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

obj MongoJobStore(JobStore) {
    has _db: Any,
        _collection: str;

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

obj MemoryJobStore(JobStore) {
    has _jobs: dict[str, dict] | None = None;

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
    has _apscheduler: Any | None = None,
        _system_user_id: str = '__system__',
        _store: JobStore | None = None,
        _server: Any | None = None,
        _user_exists_cache: dict[str, float] | None = None,
        _user_exists_ttl: float = 30.0;

    def postinit -> None;
    static def instance -> JacScaleScheduler;
    def setup(system_user_id: str, server: Any | None = None) -> None;
    def start -> None;
    def stop(drain: bool = False) -> None;
    def register_static_tasks(walkers: dict, functions: dict, server: Any) -> None;
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
