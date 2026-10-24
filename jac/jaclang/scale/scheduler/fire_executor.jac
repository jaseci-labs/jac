import from apscheduler.executors.base { run_job }
import from apscheduler.executors.pool { ThreadPoolExecutor }

class ScheduledRun {
    def init(self: any, job: any, run_time: any);
    def __getattr__(self: any, name: str) -> any;
    def __str__(self: any) -> str;
}

class FireTimeExecutor(ThreadPoolExecutor) {
    def _do_submit_job(self: any, job: any, run_times: list[any]);
}
