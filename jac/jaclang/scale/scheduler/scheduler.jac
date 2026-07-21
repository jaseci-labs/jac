import logging;
import datetime;
import from typing { Any }
import from uuid { uuid4 }
import from jaclang.scale._optdeps.apscheduler {
    BackgroundScheduler,
    CronTrigger,
    ThreadPoolExecutor,
    HAS_APSCHEDULER
}
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.runtimelib.scheduler { Scheduler, ScheduleTrigger }
import from jaclang.scale.persistence.db { get_mongo_client }
import from jaclang.scale.persistence.mongo_db { MongoDb }

glob _jaclang_scale_scheduler: (JacScaleScheduler | None) = None,
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

obj SchedulerLeaderLease {
    has _db: Any,
        _collection: str = 'scheduler_leases',
        _lease_key: str = 'scheduler',
        _holder_id: str = '',
        _ttl: float = 30.0,
        _thread: Any | None = None,
        _stop_event: Any | None = None,
        is_leader: bool = False,
        on_gain: Any | None = None,
        on_lose: Any | None = None,
        on_tick: Any | None = None;

    def postinit -> None;
    def start -> None;
    def stop(release: bool = True) -> None;
    def _tick -> None;
    def _run_loop -> None;
}

obj JacScaleScheduler {
    has _apscheduler: Any | None = None,
        _system_user_id: str = '__system__',
        _store: JobStore | None = None,
        _server: Any | None = None,
        _user_exists_cache: dict[str, float] | None = None,
        _user_exists_ttl: float = 30.0,
        _lease: SchedulerLeaderLease | None = None,
        _scheduled_sigs: dict[str, str] | None = None;

    def postinit -> None;
    static def instance -> JacScaleScheduler;
    def setup(system_user_id: str, server: Any | None = None) -> None;
    def start -> None;
    def stop(drain: bool = False) -> None;
    def start_coordinated(walkers: dict, functions: dict, server: Any) -> None;
    def register_static_tasks(walkers: dict, functions: dict, server: Any) -> None;
    def register_dynamic_tasks_from_db(quiet: bool = False) -> None;
    def _is_effectively_leader -> bool;
    def _reconcile_dynamic_jobs -> None;
    def _job_signature(spec: TriggerSpec, args: dict | None) -> str;
    def create_job(
        name: str, spec: TriggerSpec, created_by: str, args: dict | None = None
    ) -> dict;

    def list_jobs(
        limit: int | None = None,
        offset: int = 0,
        trigger: str | None = None,
        created_by: str | None = None
    ) -> tuple[list[dict], int];

    def get_job(job_id: str) -> (dict | None);
    def update_job(
        job_id: str,
        spec: TriggerSpec,
        acting_as: str | None = None,
        args: dict | None = None
    ) -> (dict | None);

    def delete_job(job_id: str, acting_as: str | None = None) -> bool;
    def _execute_task(
        name: str,
        user_id: str,
        is_walker: bool,
        job_id: str | None = None,
        args: dict | None = None
    ) -> None;

    def _schedule_apscheduler_job(
        job_id: str,
        name: str,
        spec: TriggerSpec,
        user_id: str,
        is_walker: bool = True,
        args: dict | None = None
    ) -> None;

    def _record_run(job_id: str, status: str, error: str | None = None) -> None;
    def _date_has_passed(date_str: Any) -> bool;
    def _mark_failed(job_id: str | None, reason: str) -> None;
    def _user_is_live(user_id: str) -> bool;
    def _require_store -> JobStore;
}
